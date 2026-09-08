# SPEC: investigación teórica y justificación de NPB como proxy

> Parte de Nico (persona #4). Cubre el criterio de la rúbrica a nivel
> teórico/comparativo: qué es SPEC, por qué **no** lo ejecutamos y por qué las
> **NAS Parallel Benchmarks (NPB)** son un sustituto válido y gratuito para la
> parte práctica.

## 1. Qué es SPEC

**SPEC** (Standard Performance Evaluation Corporation) es un consorcio sin fines
de lucro fundado en 1988 que agrupa a fabricantes de hardware, universidades y
centros de investigación. Su objetivo es producir **suites de benchmarks
estandarizadas** con reglas de ejecución (*run rules*) y un proceso de revisión
de resultados, de modo que los números publicados por distintos vendedores sean
comparables entre sí en lugar de ser cifras de marketing.

A diferencia de un microbenchmark aislado (como STREAM, que mide solo ancho de
banda), las suites de SPEC buscan representar **cargas de trabajo reales y
variadas**: compiladores, resolución de ecuaciones diferenciales, química
computacional, renderizado, compresión, etc. Esa variedad es justamente lo que
las hace interesantes para nuestro caso, porque exponen a la vez cuellos de
botella de cómputo, de memoria y de comunicación.

### Suites relevantes para computación paralela

| Suite | Qué mide | Relación con el caso |
| --- | --- | --- |
| **SPEC CPU 2017** | Rendimiento de CPU y subsistema de memoria en cargas enteras (`SPECint`) y de punto flotante (`SPECfp`). Se ejecuta en modo **speed** (una copia, latencia) y **rate** (varias copias, throughput). | Muestra el contraste latencia vs. throughput dentro de un mismo nodo. |
| **SPEC OMP 2012** | Escalamiento de aplicaciones paralelizadas con **OpenMP** (memoria compartida). | Referencia directa para nuestro barrido de hilos con OpenMP. |
| **SPEC MPI 2007** | Aplicaciones **MPI** de memoria distribuida corriendo en clústeres. | Aísla el **overhead de comunicación**, el corazón de la brecha del caso. |
| **SPEC ACCEL / SPEChpc** | Cargas para aceleradores (OpenACC, OpenMP target, CUDA) y HPC híbrido MPI+OpenMP. | Extiende la discusión a GPU y modelos híbridos. |

### Métricas típicas

SPEC reporta una **razón (ratio)** respecto a una máquina de referencia fija, no
GFLOPS crudos: cada resultado se normaliza contra el tiempo de esa máquina base y
luego se toma la **media geométrica** de todos los programas de la suite. Se
distingue entre:

- **speed** — cuánto tarda una sola copia del programa (mide latencia/tiempo).
- **rate** — cuántas copias concurrentes se resuelven por unidad de tiempo (mide
  throughput y, de paso, presión sobre el ancho de banda compartido).

La media geométrica evita que un solo programa muy rápido o muy lento domine el
resultado agregado, algo que un promedio aritmético sí permitiría.

## 2. Por qué NO ejecutamos SPEC

SPEC es de **licencia paga**: las suites (SPEC CPU 2017, OMP, MPI, etc.) se
adquieren mediante una licencia comercial —con descuento académico, pero no
gratuita— y sus *run rules* prohíben distribuir el código fuente o los binarios.
En el marco de este proyecto:

1. No tenemos la licencia ni el presupuesto para adquirirla.
2. No podríamos versionar sus fuentes en el repositorio sin violar la licencia.
3. Reproducir sus resultados oficiales exige hardware y configuraciones
   certificadas que no tenemos (la Mac de referencia corre Docker sobre una VM,
   ver [maquina-referencia](maquina-referencia.md)).

Por eso SPEC se cubre **a nivel teórico/comparativo** en este documento y se
**sustituye por NPB** para la parte práctica, tal como indica la sección 3 del
plan general.

## 3. Por qué NPB es un proxy válido

Las **NAS Parallel Benchmarks (NPB)** fueron desarrolladas por el *NASA Advanced
Supercomputing Division* (Bailey et al., 1994) precisamente para evaluar
supercomputadoras paralelas con cargas derivadas de aplicaciones reales de
dinámica de fluidos computacional (CFD). Son el sustituto natural de SPEC porque:

- Son **abiertas y gratuitas** (se descargan de la NASA), así que podemos
  versionarlas y reproducirlas sin problemas de licencia.
- Cubren **cargas de trabajo variadas**, igual que SPEC: mezclan kernels que
  estresan el cómputo con otros que estresan la memoria y la comunicación.
- Vienen en implementaciones **serial, OpenMP (NPB-OMP) y MPI (NPB-MPI)**, lo que
  nos permite medir el **overhead de comunicación de MPI frente a OpenMP** sobre
  el *mismo* algoritmo — el cuello de botella que nos asignaron.

### Los benchmarks de la suite NPB

| Código | Tipo | Qué estresa | Analogía con el caso |
| --- | --- | --- | --- |
| **EP** | Kernel (Embarrassingly Parallel) | Cómputo puro, casi sin comunicación. | Extremo compute-bound, como HPL. |
| **MG** | Kernel (MultiGrid) | Comunicación estructurada y jerárquica de memoria. | Sensible al ancho de banda. |
| **CG** | Kernel (Conjugate Gradient) | Accesos irregulares a memoria y comunicación. | Directamente análogo a HPCG. |
| **FT** | Kernel (Fast Fourier Transform) | Comunicación *all-to-all* intensa. | Peor caso de overhead de red. |
| **IS** | Kernel (Integer Sort) | Comunicación y latencia de memoria. | Contracara de EP. |
| **BT / SP / LU** | Pseudo-aplicaciones (CFD) | Mezcla de cómputo, memoria y comunicación. | Cargas "reales" variadas, como SPEC. |

### Clases (tamaño del problema)

NPB define **clases** que escalan el tamaño del problema: `S` y `W` (prueba),
`A`, `B`, `C` (estándar), y `D`, `E`, `F` (grandes, para clústeres). Para la Mac
de referencia usaremos clases pequeñas/medias (`A`–`C`) según la memoria
disponible; la clase se documenta junto a cada corrida para que los resultados
sean comparables.

### Métrica de NPB

NPB reporta **Mop/s total** (millones de operaciones por segundo) y **Mop/s por
proceso/hilo**, además del tiempo. Esa métrica es la que parsea
`scripts/parse_results.py` para el barrido, y con ella construimos las curvas de
escalamiento y eficiencia para colocar los kernels en el modelo Roofline junto a
HPL, HPCG y STREAM.

## 4. Cómo encaja en la tesis del proyecto

La tesis del caso es que la brecha entre el rendimiento **pico** (HPL) y el
**real** (HPCG, ~1% del pico) casi nunca la causa el cómputo, sino la **memoria
y la comunicación**. NPB nos deja *demostrar esa misma brecha con un solo código
base*: al correr el mismo kernel (p. ej. **CG** o **FT**) en OpenMP y luego en
MPI, aislamos cuánto rendimiento se pierde por el overhead de comunicación al
pasar de memoria compartida a memoria distribuida. Es el equivalente barato y
reproducible de lo que SPEC MPI mediría en un clúster certificado.

## 5. Referencias

- Bailey, D. et al. (1994). *The NAS Parallel Benchmarks*. NASA Ames Research
  Center, Technical Report RNR-94-007.
- Dongarra, J., Luszczek, P. y Petitet, A. (2003). *The LINPACK Benchmark: Past,
  Present and Future*. Concurrency and Computation: Practice and Experience,
  15(9), 803-820.
- Dongarra, J., Heroux, M. A. y Luszczek, P. (2016). *High-Performance
  Conjugate-Gradient Benchmark: A New Metric for Ranking High-Performance
  Computing Systems*. Int. J. of HPC Applications, 30(1), 3-10.
- Williams, S., Waterman, A. y Patterson, D. (2009). *Roofline: An Insightful
  Visual Performance Model for Multicore Architectures*. Communications of the
  ACM, 52(4), 65-76.
- Standard Performance Evaluation Corporation. *SPEC CPU 2017, SPEC OMP 2012 y
  SPEC MPI 2007 documentation*. https://www.spec.org
