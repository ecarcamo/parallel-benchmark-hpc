# Benchmark y Rendimiento de Aplicaciones Paralelas

Proyecto del Caso 4 de Computación Paralela y Distribuida. Comparamos cargas
compute-bound y memory-bound para observar cómo el cómputo, el ancho de banda y
la comunicación afectan el rendimiento. Los resultados se complementan con dos
apps propias y un análisis mediante el modelo Roofline.

## Requisitos

Solo se necesita [Docker Desktop](https://www.docker.com/products/docker-desktop/)
en macOS o Windows, o Docker Engine y el plugin Compose en Linux. No se requiere
instalar compiladores, MPI ni BLAS en el sistema anfitrión.

## Construir y entrar al entorno

Desde la raíz del repositorio:

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml run --rm hpc
```

El segundo comando abre una consola dentro de Ubuntu, con el repositorio montado
en `/work`. Para ejecutar un comando sin entrar interactivamente:

```bash
docker compose -f docker/docker-compose.yml run --rm hpc \
  bash -lc 'source scripts/env.sh && echo listo'
```

En Apple Silicon la imagen debe construirse de forma nativa para `arm64`; no usar
`--platform linux/amd64`, porque emula x86 y alteraría las mediciones.

## Compilar y correr

Dentro del contenedor, primero carga el entorno común:

```bash
source scripts/env.sh
./scripts/fetch_benchmarks.sh
```

Cada responsable compila su benchmark dentro de `benchmarks/`. Para correr un
barrido de hilos y guardar los logs:

```bash
./scripts/run_sweep.sh stream './benchmarks/stream'
```

El script usa 1, 2, 4 y 8 hilos. Ajustar esa lista en `scripts/run_sweep.sh` a
los cores disponibles en la máquina de referencia antes de las corridas oficiales.

## Resultados y análisis

Los logs van a `results/<benchmark>/threads_<N>.log`. Una vez que cada responsable
haya definido la regex de su métrica en `scripts/parse_results.py`, se genera el
CSV consolidado con:

```bash
python3 scripts/parse_results.py
```

El resultado es `results/summary.csv`; las gráficas y el notebook de Roofline se
guardan en `analysis/`. Los `.log` y CSV se versionan porque son la evidencia de
las mediciones.

## Máquina de referencia

Las corridas oficiales se realizan en la Mac de Nico, siempre en este contenedor.
**Pendiente de completar antes de publicar resultados:** modelo/chip, cores lógicos
y físicos, RAM y versión de macOS. Se pueden obtener con:

```bash
sysctl -n machdep.cpu.brand_string
sysctl -n hw.ncpu hw.physicalcpu hw.memsize
sw_vers
```

Docker en macOS se ejecuta dentro de una VM ligera; por ello los números no son
100% bare-metal. Como todas las mediciones se harán en el mismo entorno, las
comparaciones internas siguen siendo válidas. También se debe ejecutar con el
cargador conectado y sin otras aplicaciones pesadas para minimizar thermal
throttling.

## Estructura

```text
.
├── docker/       # imagen y Compose del entorno portátil
├── scripts/      # entorno, descarga, barridos y parsing
├── benchmarks/   # HPL, HPCG, NPB y STREAM
├── configs/      # HPL.dat e inputs
├── apps/         # N-body y stencil (workloads propios)
├── results/      # logs y CSV procesados
├── analysis/     # gráficas y Roofline
└── docs/         # plan, informe y presentación
```

## Equipo

| Persona | Responsabilidad |
| --- | --- |
| Luis Palacios | Estructura, Docker y scripts base; también presentación. |
| Diego | HPL/LINPACK: compilación, tuning y barridos. |
| Roberto | HPCG y STREAM; contraste compute-bound vs. memory-bound. |
| Nico | Investigación teórica de SPEC, NPB y Mac de referencia. |
| Esteban | Apps N-body y stencil, Roofline, informe y presentación final. |

## Convención de trabajo

El equipo acordó integrar directamente en `main`. Antes de integrar un cambio,
revisar que no rompa la reproducción en Docker y mantener los resultados crudos
y CSV bajo control de versiones. Si se vuelve a trabajar con ramas, usar una rama
por benchmark y abrir Pull Request antes de fusionarla.
