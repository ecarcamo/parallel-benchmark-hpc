/*
 * stencil.c — Difusion de calor 3D por el metodo de Jacobi (stencil de 7
 * puntos). Caso de uso: simulacion termica de un material solido.
 *
 * Este kernel es el extremo MEMORY-BOUND de nuestro estudio, la contracara
 * exacta de nbody.c. Por cada punto de la malla se hacen muy pocas
 * operaciones (sumar 6 vecinos y dos multiplicaciones) pero hay que traer
 * mucho dato de memoria. La intensidad aritmetica es baja (< 1 flop/byte),
 * asi que en el modelo Roofline cae sobre la recta inclinada del ancho de
 * banda, del mismo lado que HPCG y limitado por STREAM.
 *
 * La malla se dimensiona a proposito MUCHO mas grande que la cache (varios
 * cientos de MB) para que el limitante sea DRAM y no la cache: si cupiera
 * en cache el kernel dejaria de ser memory-bound y perderia sentido.
 *
 * Paralelismo: OpenMP sobre el plano exterior. Barrido de hilos via
 * OMP_NUM_THREADS desde run_apps.sh.
 *
 * Metrica: GFLOP/s efectivos y ancho de banda efectivo (GB/s), que se
 * puede contrastar directo contra el pico de STREAM.
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifdef _OPENMP
#include <omp.h>
#endif

/* flops por punto interior, contados exactamente sobre el kernel de abajo:
 * suma de 6 vecinos (5 sumas) + (sum6 + center) (1 suma) + cc*... (1 mul) +
 * cw*... (1 mul) = 6 sumas + 2 mul = 8 flops. */
#define FLOPS_PER_POINT 8.0

static double wall_seconds(void) {
#ifdef _OPENMP
    return omp_get_wtime();
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
#endif
}

int main(int argc, char **argv) {
    /* Parametros por env:
     *   STENCIL_N     lado de la malla cubica NxNxN (default 384)
     *   STENCIL_STEPS iteraciones de Jacobi         (default 20)
     * default 384^3 doubles * 2 arreglos ~= 906 MB: bien por encima de
     * cualquier cache, garantiza regimen memory-bound. */
    long N = (getenv("STENCIL_N")) ? atol(getenv("STENCIL_N")) : 384;
    int steps = (getenv("STENCIL_STEPS")) ? atoi(getenv("STENCIL_STEPS")) : 20;

    (void)argc; (void)argv;

    if (N < 3) { fprintf(stderr, "stencil: STENCIL_N debe ser >= 3\n"); return 1; }

    long NN = N * N;
    long total = N * N * N;
    size_t bytes = sizeof(double) * (size_t)total;

    double *A = malloc(bytes);
    double *B = malloc(bytes);
    if (!A || !B) {
        fprintf(stderr, "stencil: sin memoria para N=%ld (%.1f MB x2)\n",
                N, (double)bytes / 1e6);
        return 1;
    }

    /* inicializacion en paralelo: importa por la politica first-touch de
     * NUMA/paginas — que cada hilo toque la memoria que luego usara. */
    #pragma omp parallel for schedule(static)
    for (long i = 0; i < total; i++) {
        A[i] = 0.0;
        B[i] = 0.0;
    }
    /* borde caliente en una cara (condicion de frontera de Dirichlet) */
    #pragma omp parallel for schedule(static)
    for (long j = 0; j < N; j++)
        for (long k = 0; k < N; k++)
            A[(long)0 * NN + j * N + k] = 1.0;

    const double cc = 0.5;         /* peso del punto central */
    const double cw = 0.5 / 6.0;   /* peso de cada uno de los 6 vecinos */

    int nthreads = 1;
#ifdef _OPENMP
    #pragma omp parallel
    {
        #pragma omp single
        nthreads = omp_get_num_threads();
    }
#endif

    double t0 = wall_seconds();

    for (int s = 0; s < steps; s++) {
        /* stencil de 7 puntos sobre los puntos interiores. El plano i es
         * el bucle paralelo. Cada hilo procesa un bloque de planos. */
        #pragma omp parallel for schedule(static)
        for (long i = 1; i < N - 1; i++) {
            for (long j = 1; j < N - 1; j++) {
                for (long k = 1; k < N - 1; k++) {
                    long c = i * NN + j * N + k;
                    double sum6 = A[c - NN] + A[c + NN]   /* +/- i */
                                + A[c - N]  + A[c + N]     /* +/- j */
                                + A[c - 1]  + A[c + 1];    /* +/- k */
                    B[c] = cc * A[c] + cw * sum6;
                }
            }
        }
        /* intercambio de buffers (ping-pong): B pasa a ser el nuevo A */
        double *tmp = A; A = B; B = tmp;
    }

    double t1 = wall_seconds();
    double elapsed = t1 - t0;

    /* --- metricas --- */
    long interior = (N - 2) * (N - 2) * (N - 2);
    double total_flops = FLOPS_PER_POINT * (double)interior * (double)steps;
    double gflops = (total_flops / elapsed) / 1e9;

    /* Trafico DRAM por iteracion (modelo compulsorio, sin reuso perfecto):
     * se lee el arreglo A completo y se escribe B completo -> 2 arreglos.
     * Contamos 3 movimientos de 8 bytes por punto (leer A[c] efectivo,
     * traer el frente de vecinos que no cabe en cache, escribir B[c]) como
     * estimacion conservadora del trafico real medido con contadores.
     * bytes = 3 * 8 * total por paso. */
    double bytes_dram = 3.0 * 8.0 * (double)total * (double)steps;
    double gbps = (bytes_dram / elapsed) / 1e9;
    double ai = total_flops / bytes_dram; /* ~ 8 / 24 = 0.33 flop/byte */

    /* checksum anti-optimizacion */
    double checksum = 0.0;
    #pragma omp parallel for reduction(+:checksum) schedule(static)
    for (long i = 0; i < total; i++) checksum += A[i];

    printf("=== STENCIL RESULT ===\n");
    printf("app=stencil\n");
    printf("grid_n=%ld\n", N);
    printf("grid_points=%ld\n", total);
    printf("steps=%d\n", steps);
    printf("threads=%d\n", nthreads);
    printf("flops_per_point=%.0f\n", FLOPS_PER_POINT);
    printf("total_flops=%.6e\n", total_flops);
    printf("time_s=%.6f\n", elapsed);
    printf("gflops=%.4f\n", gflops);
    printf("bytes_dram=%.6e\n", bytes_dram);
    printf("bandwidth_gbps=%.4f\n", gbps);
    printf("arithmetic_intensity=%.4f\n", ai);
    printf("checksum=%.6e\n", checksum);
    printf("bound=memory\n");
    printf("=== END STENCIL RESULT ===\n");

    free(A); free(B);
    return 0;
}
