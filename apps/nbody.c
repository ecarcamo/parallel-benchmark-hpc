/*
 * nbody.c — Simulacion gravitacional N-body de todos-contra-todos (O(n^2)).
 *
 * Caso de uso: formacion de galaxias. Cada cuerpo siente la atraccion de
 * TODOS los demas, asi que el trabajo crece como n^2. Este kernel es el
 * extremo COMPUTE-BOUND de nuestro estudio: la intensidad aritmetica es
 * alta (mucho calculo por cada byte movido de memoria), asi que en el
 * modelo Roofline cae pegado al techo de computo, del mismo lado que HPL.
 *
 * Paralelismo: OpenMP. El barrido de hilos lo controla run_apps.sh via
 * OMP_NUM_THREADS, igual que el resto de benchmarks del repo.
 *
 * Metrica: GFLOP/s efectivos. Contamos FLOPS con la convencion estandar de
 * la literatura N-body (~20 flops por interaccion, ver Nyland et al., GPU
 * Gems 3, cap. 31), para que el numero sea comparable con lo que reporta
 * la comunidad de HPC y no un conteo casero.
 *
 * Compilacion: ./scripts/build_apps.sh  (o ver el bloque de flags abajo).
 */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifdef _OPENMP
#include <omp.h>
#endif

/* flops por interaccion par-a-par: convencion estandar de la literatura.
 * dx,dy,dz (3 restas) + r2 = dx*dx+dy*dy+dz*dz+eps (3 mul + 3 sumas) +
 * inv_r3 = 1/(r2*sqrt(r2)) (~9 contando el rsqrt) + fuerza a las 3
 * componentes (3 mul + 3 sumas). Se redondea a 20 por convencion. */
#define FLOPS_PER_INTERACTION 20.0

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
    /* Parametros por env para no recompilar entre corridas:
     *   NBODY_N     numero de cuerpos      (default 8192)
     *   NBODY_STEPS pasos de integracion   (default 10)
     * n moderado a proposito: cabe en cache, asi la carga es de computo
     * puro y no de memoria — justo lo que queremos demostrar. */
    long n = (getenv("NBODY_N")) ? atol(getenv("NBODY_N")) : 8192;
    int steps = (getenv("NBODY_STEPS")) ? atoi(getenv("NBODY_STEPS")) : 10;
    const double dt = 0.01;
    const double eps2 = 1e-9; /* softening, evita division por cero */

    (void)argc; (void)argv;

    if (n < 2) { fprintf(stderr, "nbody: NBODY_N debe ser >= 2\n"); return 1; }

    /* Estructura de arreglos (SoA): mejor para vectorizar que un arreglo
     * de structs. 4 arreglos de posicion/masa + 3 de velocidad. */
    double *x = malloc(sizeof(double) * n);
    double *y = malloc(sizeof(double) * n);
    double *z = malloc(sizeof(double) * n);
    double *m = malloc(sizeof(double) * n);
    double *vx = calloc(n, sizeof(double));
    double *vy = calloc(n, sizeof(double));
    double *vz = calloc(n, sizeof(double));
    if (!x || !y || !z || !m || !vx || !vy || !vz) {
        fprintf(stderr, "nbody: sin memoria para n=%ld\n", n);
        return 1;
    }

    /* Condiciones iniciales deterministas (semilla fija) para que la
     * corrida sea reproducible entre maquinas. */
    srand(1234);
    for (long i = 0; i < n; i++) {
        x[i] = (double)rand() / RAND_MAX - 0.5;
        y[i] = (double)rand() / RAND_MAX - 0.5;
        z[i] = (double)rand() / RAND_MAX - 0.5;
        m[i] = (double)rand() / RAND_MAX + 0.1;
    }

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
        /* Para cada cuerpo i acumulamos la aceleracion contra todos los j.
         * El bucle i es el paralelo: cada hilo toma un bloque de cuerpos y
         * lee el arreglo completo j (que se reusa desde cache: de ahi la
         * alta intensidad aritmetica). */
        #pragma omp parallel for schedule(static)
        for (long i = 0; i < n; i++) {
            double ax = 0.0, ay = 0.0, az = 0.0;
            const double xi = x[i], yi = y[i], zi = z[i];
            for (long j = 0; j < n; j++) {
                double dx = x[j] - xi;
                double dy = y[j] - yi;
                double dz = z[j] - zi;
                double r2 = dx * dx + dy * dy + dz * dz + eps2;
                double inv_r = 1.0 / sqrt(r2);
                double inv_r3 = inv_r * inv_r * inv_r;
                double f = m[j] * inv_r3;
                ax += dx * f;
                ay += dy * f;
                az += dz * f;
            }
            /* integracion (leapfrog simplificado): actualiza velocidad */
            vx[i] += dt * ax;
            vy[i] += dt * ay;
            vz[i] += dt * az;
        }
        /* actualiza posiciones en un segundo barrido (evita dependencias) */
        #pragma omp parallel for schedule(static)
        for (long i = 0; i < n; i++) {
            x[i] += dt * vx[i];
            y[i] += dt * vy[i];
            z[i] += dt * vz[i];
        }
    }

    double t1 = wall_seconds();
    double elapsed = t1 - t0;

    /* --- metricas --- */
    double total_flops = FLOPS_PER_INTERACTION * (double)n * (double)n * (double)steps;
    double gflops = (total_flops / elapsed) / 1e9;

    /* Intensidad aritmetica (operational intensity) para el Roofline.
     * Trafico DRAM compulsorio por paso: se lee el arreglo de cuerpos una
     * vez (x,y,z,m = 32 bytes/cuerpo). El bucle interno j reusa esos datos
     * desde cache, no desde DRAM. AI = flops / bytes_DRAM.
     * AI = (20*n^2) / (n*32) = 0.625 * n  -> crece con n, muy alta. */
    double bytes_dram = 32.0 * (double)n * (double)steps;
    double ai = total_flops / bytes_dram;

    /* checksum para que el compilador no elimine el computo */
    double checksum = 0.0;
    for (long i = 0; i < n; i++) checksum += x[i] + vx[i];

    printf("=== NBODY RESULT ===\n");
    printf("app=nbody\n");
    printf("n_bodies=%ld\n", n);
    printf("steps=%d\n", steps);
    printf("threads=%d\n", nthreads);
    printf("flops_per_interaction=%.0f\n", FLOPS_PER_INTERACTION);
    printf("total_flops=%.6e\n", total_flops);
    printf("time_s=%.6f\n", elapsed);
    printf("gflops=%.4f\n", gflops);
    printf("bytes_dram=%.6e\n", bytes_dram);
    printf("arithmetic_intensity=%.4f\n", ai);
    printf("checksum=%.6e\n", checksum);
    printf("bound=compute\n");
    printf("=== END NBODY RESULT ===\n");

    free(x); free(y); free(z); free(m); free(vx); free(vy); free(vz);
    return 0;
}
