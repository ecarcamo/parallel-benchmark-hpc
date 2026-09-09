# Fundamentos científicos y fuentes

Documento de respaldo del Caso 4. Para **cada afirmación** que hacemos en la
presentación hay aquí una fuente verificable (paper, lista oficial TOP500 o
documentación de laboratorio/industria). Nada de foros ni Wikipedia: solo
fuentes primarias, accesibles y actualizadas.

> Regla de uso: si en la presentación alguien pregunta "¿de dónde sacaron
> eso?", la respuesta está en este documento con su cita.

---

## 1. La tesis central, con datos oficiales (TOP500, noviembre 2025)

**Afirmación:** el número que sale en las noticias (el pico de FLOPS en HPL)
no es el rendimiento que se ve en aplicaciones reales. La brecha es enorme y
el cuello de botella casi nunca es el cómputo, sino la **memoria** y la
**comunicación**.

**Evidencia oficial** — lista TOP500 y HPCG de noviembre 2025, sistema #1
**El Capitan** (LLNL, HPE Cray EX255a, AMD MI300A):

| Métrica | Valor oficial | Qué significa |
| --- | --- | --- |
| HPL (Rmax) | **1,809 PFlop/s** (1.809 EFlop/s) | Pico sostenido en álgebra densa |
| Rpeak (teórico) | 2,821 PFlop/s | Máximo teórico del hardware |
| HPCG | **17.41 PFlop/s** | Carga realista (matriz dispersa) |
| HPL-MxP (precisión mixta) | 16.7 EFlop/s | La métrica que persigue la era de IA |
| Cores | 11,340,000 | — |
| Potencia | 29,685 kW (~29.7 MW) | 60.94 GFlop/s por watt |

**Las dos brechas que vamos a explicar:**

1. **HPCG / HPL = 17.41 / 1809 = 0.96 %.** El sistema que era #1 del mundo (en
   noviembre de 2025) rinde menos del **1 %** de su número estrella cuando la
   carga es realista — es **~104× más lento** consigo mismo (1809 / 17.41).
   Este es el corazón de la presentación.
2. **Rmax / Rpeak = 1809 / 2821 = 64 %.** Incluso HPL, la carga más amable,
   deja ~36 % del hardware sobre la mesa. **HPL es rendimiento medido (Rmax),
   no el pico teórico**; el pico teórico (Rpeak) es el que nunca se alcanza.

> **Precisión de las cifras (evitar que un profesor nos corrija):**
> el **104×** es de El Capitan (1809 / 17.41). El **~19×** que a veces
> mencionamos es de **nuestra Mac** (121.9 / 6.5), no de El Capitan — no
> mezclar los dos. Y la secuencia correcta es **Rpeak 2821 → HPL/Rmax 1809 →
> HPCG 17.41**: solo Rpeak es "pico teórico".

> **Actualización TOP500 (junio de 2026):** en la lista de junio de 2026,
> **LineShine** (China, NSCS Shenzhen, 2.198 EFlop/s en HPL) debutó como #1 y
> **desplazó a El Capitan al #2**. Nuestro análisis usa la lista de
> **noviembre de 2025**, donde El Capitan era #1; por eso siempre lo decimos
> con fecha: *"#1 en noviembre de 2025"*, nunca "#1 hoy".

**Dato de contexto (misma lista):** JUPITER Booster (Alemania) se volvió el
primer sistema exaescala de Europa con 1.000 EFlop/s en HPL, pero **aún no
envió resultado de HPCG** — patrón habitual: HPL se reporta siempre, HPCG
cuesta y a veces ni se mide, justo porque expone lo incómodo.

Fuentes: [TOP500 Highlights nov 2025](https://top500.org/lists/top500/2025/11/highs/) ·
[Lista HPCG nov 2025](https://top500.org/lists/hpcg/2025/11/) ·
[Nota de LLNL](https://www.llnl.gov/article/53596/el-capitan-retains-title-worlds-fastest-supercomputer-latest-top500-list)

---

## 2. Los benchmarks: qué mide cada uno y en qué fuente se sostiene

| Benchmark | Qué mide | Cuello que expone | Fuente base |
| --- | --- | --- | --- |
| **HPL / LINPACK** | Álgebra lineal densa (factorización LU), pico de punto flotante | Compute-bound; poco representativo de apps reales | Dongarra, Luszczek & Petitet (2003) |
| **HPCG** | Gradiente conjugado con matriz **dispersa**, accesos irregulares | Memory-bound + comunicación; la contracara de HPL | Dongarra, Heroux & Luszczek (2016) |
| **STREAM** | Ancho de banda de memoria sostenible (Copy/Scale/Add/Triad) | Techo de ancho de banda; el porqué de la caída de HPCG | McCalpin (1995) |
| **NPB (proxy de SPEC)** | Kernels de CFD de la NASA (CG, EP, …), OpenMP vs MPI | Overhead de comunicación memoria compartida vs distribuida | Bailey et al. (1994) |
| **Apps propias** | N-body (compute) y stencil de calor 3D (memory) | Los dos extremos, medidos por nosotros | Diseño propio + marco Roofline |

Nota sobre **SPEC**: se estudia a nivel teórico porque es de **licencia
paga**; en la parte práctica se sustituye por las NAS Parallel Benchmarks,
que son gratuitas y cubren el mismo propósito de "cargas variadas
representativas". El detalle está en [spec-investigacion.md](spec-investigacion.md).

---

## 3. El marco teórico (los tres pilares del análisis)

### 3.1 El "muro de memoria" — por qué existe la brecha

Wulf y McKee (1995) observaron lo "obvio": la velocidad del procesador y la
de la DRAM mejoran **ambas de forma exponencial, pero a ritmos distintos**.
La diferencia entre dos exponenciales crece exponencialmente, así que el
procesador termina esperando a la memoria. Predijeron que ese hueco sería el
limitante dominante — y 30 años después El Capitan rindiendo <1 % en HPCG lo
confirma. Es la raíz teórica de todo el proyecto.

> Wulf, W. A. & McKee, S. A. (1995). *Hitting the Memory Wall: Implications
> of the Obvious.* ACM SIGARCH Computer Architecture News, 23(1), 20-24.
> DOI [10.1145/216585.216588](https://dl.acm.org/doi/10.1145/216585.216588)

### 3.2 El modelo Roofline — cómo lo visualizamos

Williams, Waterman y Patterson (2009) proponen graficar el rendimiento
(GFLOP/s) contra la **intensidad aritmética** (FLOP por byte movido de
memoria) en ejes log-log. Aparecen dos techos:

- una **recta inclinada** = ancho de banda × intensidad (límite de memoria),
- una **línea horizontal** = pico de cómputo de la máquina.

El **punto de quiebre** (ridge point) separa las cargas: a la izquierda uno
está limitado por memoria; a la derecha, por cómputo. Es la herramienta que
usamos para poner HPL, HPCG, STREAM y nuestras dos apps en **una sola imagen
que explica todo**.

> Williams, S., Waterman, A. & Patterson, D. (2009). *Roofline: An Insightful
> Visual Performance Model for Multicore Architectures.* Communications of the
> ACM, 52(4), 65-76.
> DOI [10.1145/1498765.1498785](https://dl.acm.org/doi/abs/10.1145/1498765.1498785)

### 3.3 Por qué HPCG es un mejor termómetro que HPL

Dongarra, Heroux y Luszczek (2016) crearon HPCG precisamente porque HPL dejó
de correlacionar con las aplicaciones reales: HPL premia máquinas con mucha
FPU aunque tengan memoria e interconexión pobres. HPCG usa un gradiente
conjugado sobre matriz dispersa, con patrones de acceso irregulares y
comunicación de halos — como la mayoría de simulaciones de ingeniería. Su
requerimiento es **> 4 Byte/FLOP** (intensidad aritmética < 0.25 flop/byte),
razón matemática por la que cae siempre en la zona memory-bound del Roofline.

> Dongarra, J., Heroux, M. A. & Luszczek, P. (2016). *High-Performance
> Conjugate-Gradient Benchmark: A New Metric for Ranking High-Performance
> Computing Systems.* Int. J. of High Performance Computing Applications,
> 30(1), 3-10. DOI [10.1177/1094342015593158](https://doi.org/10.1177/1094342015593158) ·
> [hpcg-benchmark.org](https://hpcg-benchmark.org/)

### 3.4 Balance de máquina y STREAM

McCalpin (1995) formalizó el concepto de *machine balance* (FLOP/s pico por
byte/s de ancho de banda) y creó STREAM para medir el ancho de banda
**sostenible**, no el de folleto. Detalle clave que citamos: el ancho de
banda sostenible "normalmente no está disponible en los datos publicados por
los fabricantes (quizá porque los resultados son bastante pobres)". STREAM es
hoy el estándar de facto para medir la memoria; nos da el techo inclinado del
Roofline.

> McCalpin, J. D. (1995). *Memory Bandwidth and Machine Balance in Current
> High Performance Computers.* IEEE TCCA Newsletter, dic. 1995.
> [Página oficial de STREAM (U. of Virginia)](https://www.cs.virginia.edu/stream/ref.html)

---

## 4. Esto no es solo académico: adopción en industria y laboratorios

El modelo Roofline y estos benchmarks son herramientas de producción, no
curiosidades de paper:

- **Intel** integró el análisis Roofline en **Intel Advisor**, y **NVIDIA**
  en **Nsight Compute**: hoy un ingeniero de rendimiento saca el Roofline de
  su código directo desde la herramienta del fabricante.
- **NERSC** (centro de supercómputo del Dept. de Energía de EE. UU.) documenta
  el Roofline como metodología estándar para optimizar aplicaciones en sus
  máquinas ([NERSC Roofline docs](https://docs.nersc.gov/tools/performance/roofline/)).
- Yang et al. (2020) describen cómo recolectar datos de Roofline jerárquico en
  CPUs Intel y GPUs NVIDIA con esas herramientas de producción
  ([arXiv:2009.02449](https://arxiv.org/abs/2009.02449)).
- **TOP500 + HPCG** son mantenidos por la comunidad HPC mundial y usados por
  todos los fabricantes (HPE, AMD, NVIDIA, Fujitsu) para reportar y comparar
  sistemas reales dos veces al año.

Mensaje para la presentación: *"la industria dejó de mirar solo el pico; mira
el Roofline. Nosotros hicimos lo mismo, a escala de laptop."*

---

## 5. Cómo nuestras propias mediciones confirman la literatura

No solo citamos: **reprodujimos** el fenómeno con nuestras dos apps y lo
superpusimos en el Roofline.

| Predicción de la teoría | Lo que medimos nosotros |
| --- | --- |
| HPCG es memory-bound porque exige > 4 Byte/FLOP (AI < 0.25) | Nuestro **stencil** mide AI ≈ 0.33 flop/byte y queda en la zona memory-bound, junto a HPCG |
| Una carga compute-bound escala con los cores; una memory-bound se satura | **N-body** escala 5.6× de 1→8 hilos (casi ideal); **stencil** se estanca en 3.6× tras 4 hilos al saturar el ancho de banda |
| El pico teórico no se alcanza en cargas reales | El Capitan sostiene 64 % en HPL y 0.96 % en HPCG; nuestro contraste HPL-vs-HPCG reproduce la misma forma a escala |

Esta es la parte de **creatividad** de la rúbrica: cerramos el círculo entre
el paper de 1995, la lista mundial de 2025 y nuestras propias corridas.

### Nota de metodología del Roofline (importante para el Q&A)

El **techo de ancho de banda** del Roofline es el **pico teórico publicado del
M4 Pro: 273 GB/s** ([Apple, oct. 2024](https://www.apple.com/newsroom/2024/10/apple-introduces-m4-pro-and-m4-max/)),
una fuente **independiente** de nuestras mediciones. Deliberadamente **no**
derivamos el techo del propio stencil (sería circular: el punto caería sobre la
recta por construcción). Con el techo en 273 GB/s, el stencil sostiene **~58 %
del pico** — un resultado realista para un kernel de streaming.

La corrida de **STREAM** que teníamos (32.6 GB/s, `machine=desconocido`) **no es
representativa** del M4 Pro (memoria unificada de alto ancho de banda); por eso
no se usa como techo. *Mejora pendiente para máximo rigor:* volver a correr
STREAM en la Mac (`./scripts/build_stream.sh && ./scripts/run_sweep.sh stream
'./benchmarks/stream_<N>'`) y usar ese valor medido para **confirmar**
empíricamente el techo. El **techo de cómputo** (128 GFLOP/s) sí es medido
(máximo entre HPL y nuestra N-body).

---

## 6. Referencias completas

1. Wulf, W. A. & McKee, S. A. (1995). *Hitting the Memory Wall: Implications of
   the Obvious.* ACM SIGARCH Computer Architecture News, 23(1), 20-24.
   DOI 10.1145/216585.216588
2. McCalpin, J. D. (1995). *Memory Bandwidth and Machine Balance in Current
   High Performance Computers.* IEEE TCCA Newsletter. STREAM:
   https://www.cs.virginia.edu/stream/
3. Bailey, D. et al. (1994). *The NAS Parallel Benchmarks.* NASA Ames Research
   Center, Technical Report RNR-94-007.
4. Dongarra, J., Luszczek, P. & Petitet, A. (2003). *The LINPACK Benchmark:
   Past, Present and Future.* Concurrency and Computation: Practice and
   Experience, 15(9), 803-820. DOI 10.1002/cpe.728
5. Williams, S., Waterman, A. & Patterson, D. (2009). *Roofline: An Insightful
   Visual Performance Model for Multicore Architectures.* Communications of the
   ACM, 52(4), 65-76. DOI 10.1145/1498765.1498785
6. Dongarra, J., Heroux, M. A. & Luszczek, P. (2016). *High-Performance
   Conjugate-Gradient Benchmark: A New Metric for Ranking High-Performance
   Computing Systems.* IJHPCA, 30(1), 3-10. DOI 10.1177/1094342015593158
7. Yang, C. et al. (2020). *Hierarchical Roofline Analysis: How to Collect Data
   using Performance Tools on Intel CPUs and NVIDIA GPUs.* arXiv:2009.02449
8. TOP500 (noviembre 2025). Listas HPL, HPCG y HPL-MxP. https://top500.org/lists/top500/2025/11/
9. HPCG Benchmark project. https://hpcg-benchmark.org/
10. NERSC. *Roofline Performance Model.* https://docs.nersc.gov/tools/performance/roofline/

---

## 7. Frases-bala listas para decir en vivo (cada una con su respaldo)

- *"La que era la computadora más rápida del mundo —El Capitan, #1 en noviembre
  de 2025— rinde menos del 1 % de su número estrella en una carga realista;
  104× más lenta consigo misma."* → §1, TOP500 nov 2025.
- *"El cuello de botella lo predijo un paper de 1995 y sigue vigente en
  2025."* → §3.1, Wulf & McKee.
- *"El pico teórico es marketing: ni HPL, la carga más fácil, pasa del 64 %."*
  → §1, Rmax/Rpeak.
- *"HPCG necesita más de 4 bytes por cada operación; por eso vive contra el
  muro de memoria."* → §3.3, Dongarra et al.
- *"Los fabricantes esconden el ancho de banda sostenible porque es pobre;
  por eso existe STREAM."* → §3.4, McCalpin.
- *"Intel y NVIDIA meten el Roofline en sus herramientas; nosotros lo hicimos
  a escala de laptop y da la misma forma."* → §4.
