#!/usr/bin/env bash
# Compila STREAM con un STREAM_ARRAY_SIZE calculado dinamicamente segun
# la cache detectada de la maquina, no un numero fijo.
#
# regla real de mccalpin: cada array debe ser >= 4x la suma de todas las
# last-level caches del sistema, o 1 millon de elementos, lo que sea mayor.
# stream_array_size es una macro de COMPILACION, asi que cada tamano nuevo
# implica recompilar (por eso el binario se nombra con el N adentro).
#
# uso: ./scripts/build_stream.sh
# salida: benchmarks/stream_<N> (N = STREAM_ARRAY_SIZE usado)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/benchmarks/stream.c"

if [[ ! -f "$SRC" ]]; then
  echo "build_stream: no existe $SRC — corre antes ./scripts/fetch_benchmarks.sh" >&2
  exit 1
fi

# necesitamos LLC_TOTAL_BYTES; si quien nos llama ya hizo source de
# detect_specs.sh lo reusamos, si no, lo hacemos aqui.
if [[ -z "${LLC_TOTAL_BYTES:-}" ]]; then
  DETECT_SPECS_QUIET=1 source "${ROOT_DIR}/scripts/detect_specs.sh"
fi

BYTES_PER_ELEMENT=8   # STREAM_TYPE es double
MIN_ELEMENTS=1000000  # piso de mccalpin: 1 millon de elementos

# N = techo(4 * llc_total_bytes / bytes_por_elemento), pero nunca menos
# del piso de 1 millon.
n_from_cache=$(( (4 * LLC_TOTAL_BYTES + BYTES_PER_ELEMENT - 1) / BYTES_PER_ELEMENT ))
if (( n_from_cache > MIN_ELEMENTS )); then
  STREAM_N="$n_from_cache"
else
  STREAM_N="$MIN_ELEMENTS"
fi

# redondeamos hacia arriba a multiplo de 1e6 para que el numero sea
# legible y estable entre corridas
STREAM_N=$(( ((STREAM_N + 999999) / 1000000) * 1000000 ))

# guard: 3 arrays de 8 bytes cada uno; si la huella total pasa de la
# mitad de la ram total, avisamos (no abortamos, es responsabilidad
# de quien corre decidir si sigue).
footprint_bytes=$(( 3 * BYTES_PER_ELEMENT * STREAM_N ))
mem_total_bytes=$(( ${MEM_TOTAL_KB:-0} * 1024 ))
if [[ -n "${MEM_TOTAL_KB:-}" ]] && (( mem_total_bytes > 0 )) && (( footprint_bytes > mem_total_bytes / 2 )); then
  echo "build_stream: ADVERTENCIA — huella estimada ($((footprint_bytes / 1024 / 1024))MB) supera el 50% de la RAM total ($((mem_total_bytes / 1024 / 1024))MB)" >&2
fi

if [[ "${CACHE_DETECTION_OK:-1}" == "0" ]]; then
  echo "build_stream: la deteccion de cache no fue confiable (CACHE_DETECTION_OK=0), usando piso conservador" >&2
fi

OUT="${ROOT_DIR}/benchmarks/stream_${STREAM_N}"
NTIMES_VAL="${STREAM_NTIMES:-20}"

echo "build_stream: STREAM_ARRAY_SIZE=${STREAM_N} NTIMES=${NTIMES_VAL} -> ${OUT}"

# ojo: NO usar -ffast-math ni -flto — stream valida resultados y esas
# flags habilitan que el compilador elimine loops "inutiles".
"${CC:-gcc}" -O3 -march=native -fopenmp \
  -DSTREAM_ARRAY_SIZE="${STREAM_N}" -DNTIMES="${NTIMES_VAL}" \
  "$SRC" -o "$OUT" -lm

echo "build_stream: listo -> ${OUT}"
