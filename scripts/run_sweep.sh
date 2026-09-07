#!/usr/bin/env bash
# Corre un comando variando el número de hilos y guarda logs reproducibles.
# Uso: ./scripts/run_sweep.sh <nombre> "<comando a correr>"
set -euo pipefail

if [[ "$#" -lt 2 ]]; then
  echo "Uso: $0 <nombre> \"<comando a correr>\"" >&2
  exit 64
fi

NAME="$1"
shift
CMD="$*"
THREADS_LIST=(1 2 4 8) # Ajustar según los cores reales de la Mac de referencia.
OUTDIR="results/${NAME}"
mkdir -p "$OUTDIR"

for threads in "${THREADS_LIST[@]}"; do
  echo ">> ${NAME} con ${threads} hilos"
  OMP_NUM_THREADS="$threads" bash -lc "$CMD" 2>&1 | tee "${OUTDIR}/threads_${threads}.log"
done

echo "Listo. Salidas en ${OUTDIR}/"
