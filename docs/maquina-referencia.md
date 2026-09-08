# Máquina de referencia

> Parte de Nico (persona #4): dueño de la Mac de referencia. Todas las corridas
> oficiales del proyecto salen de esta máquina y dentro del contenedor Docker,
> para que los números sean comparables entre benchmarks.

## 1. Especificaciones

| Característica | Valor |
| --- | --- |
| Chip | Apple M4 Pro |
| Identificador de modelo | `Mac16,8` |
| Arquitectura | `arm64` (Apple Silicon) |
| Cores físicos | 12 (8 de rendimiento "P" + 4 de eficiencia "E") |
| Cores lógicos | 12 (Apple Silicon **no** usa SMT/Hyper-Threading) |
| RAM | 24 GB (memoria unificada, 25 769 803 776 bytes) |
| Sistema operativo | macOS 26.6.1 (build 25G76) |

## 2. Cómo se obtuvieron

Los valores se sacaron directamente del anfitrión con las utilidades de macOS:

```bash
sysctl -n machdep.cpu.brand_string           # -> Apple M4 Pro
sysctl -n hw.model                            # -> Mac16,8
sysctl -n hw.physicalcpu hw.logicalcpu        # -> 12   12
sysctl -n hw.perflevel0.physicalcpu \
        hw.perflevel1.physicalcpu             # -> 8 (P)   4 (E)
sysctl -n hw.memsize                          # -> 25769803776  (24 GB)
uname -m                                      # -> arm64
sw_vers                                       # -> macOS 26.6.1 (25G76)
```

En Apple Silicon `hw.logicalcpu == hw.physicalcpu` porque no hay
multi-threading por core; los 12 lógicos son 12 físicos reales.

## 3. Anfitrión vs. contenedor (importante para las mediciones)

Los números de arriba son del **anfitrión** (macOS). Los benchmarks, en cambio,
corren dentro del **contenedor Linux** que Docker Desktop levanta sobre una VM
ligera. Por eso:

- Lo que "ve" el benchmark (cores y RAM disponibles) depende de lo que Docker
  Desktop le asigne a su VM, no del total físico del Mac.
- Para no depender de números fijos, `scripts/detect_specs.sh` lee `/proc` y
  `/sys` **dentro del contenedor** en cada corrida y exporta las specs reales;
  `scripts/log_header.sh` las incrusta en el bloque `#META` al inicio de cada
  log. Así cada resultado queda autodocumentado con el entorno exacto en que se
  midió, y no hay que confiar en la memoria de nadie.
- **Conviene revisar en Docker Desktop → Settings → Resources** que la VM tenga
  asignados los CPUs y la RAM suficientes antes de las corridas oficiales (por
  defecto Docker no siempre expone los 12 cores).

## 4. Implicaciones para el análisis

1. **No es bare-metal.** Docker en macOS corre en una VM, así que los valores
   absolutos no son los de un servidor dedicado. Como *todo* el equipo mide en
   el mismo entorno, las comparaciones **internas** (HPL vs. HPCG vs. NPB, o
   OpenMP vs. MPI) siguen siendo válidas; se documenta como nota de metodología,
   tal como pide la rúbrica.
2. **Arquitectura nativa `arm64`.** La imagen se construye nativa para `arm64`;
   **no** usar `--platform linux/amd64`, porque eso emula x86 con QEMU y
   destruiría las mediciones. Es también la razón por la que los `make.def` de
   NPB y los flags usan `-march=native` sin `-mcmodel=medium` (opción exclusiva
   de x86).
3. **Cores heterogéneos (P + E).** Los 8 cores de rendimiento y 4 de eficiencia
   no son iguales. En los barridos de hilos/procesos (1, 2, 4, 8, …) se espera
   escalamiento casi lineal hasta ~8 (solo cores P) y una pendiente más floja al
   pasar de 8 a 12, cuando entran los cores E. Ese "codo" en la curva es un
   hallazgo a comentar, no un error de medición.
4. **Memoria unificada.** Los 24 GB los comparten CPU y GPU. Los tamaños de
   problema (HPCG `nx/ny/nz`, HPL `N`, clase de NPB) se dimensionan de forma
   dinámica según la RAM detectada para no provocar swapping, que arruinaría los
   benchmarks memory-bound.

## 5. Protocolo de corrida (para reproducibilidad)

Antes de cada corrida oficial:

- Conectar el **cargador** y fijar el modo de energía en alto rendimiento.
- Cerrar aplicaciones pesadas (navegadores con muchas pestañas, IDEs, etc.) para
  minimizar el **thermal throttling**, que en una laptop baja la frecuencia en
  corridas largas.
- Correr siempre dentro del contenedor con `docker compose ... run --rm hpc`.
- Si el rendimiento decae entre repeticiones de un mismo barrido, dejarlo
  anotado: ese decaimiento es en sí mismo un resultado (evidencia de throttling).
