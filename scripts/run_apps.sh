#!/usr/bin/env bash
# Corre las dos apps propias barriendo hilos OpenMP y guarda un log por
# corrida con el mismo header #META que el resto del repo, para que
# parse_results.py las consuma sin casos especiales.
#
# uso: ./scripts/run_apps.sh
# variables opcionales:
#   APPS_THREADS_LIST  barrido de hilos (default "1 2 4 8")
#   NBODY_N, NBODY_STEPS, STENCIL_N, STENCIL_STEPS  (ver los .c)
set -uo pipefail  # sin -e: si una corrida falla seguimos con el resto

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NBODY_BIN="${ROOT_DIR}/apps/nbody"
STENCIL_BIN="${ROOT_DIR}/apps/stencil"

if [[ ! -x "$NBODY_BIN" || ! -x "$STENCIL_BIN" ]]; then
  echo "run_apps: faltan binarios — corre antes ./scripts/build_apps.sh" >&2
  exit 1
fi

DETECT_SPECS_QUIET=1 source "${ROOT_DIR}/scripts/detect_specs.sh"
source "${ROOT_DIR}/scripts/log_header.sh"

read -ra THREADS_ARR <<< "${APPS_THREADS_LIST:-1 2 4 8}"

# escribe header #META + salida de la app en un solo log (patron de run_npb)
run_and_log() {
  local logfile="$1" app="$2" threads="$3" binary="$4"; shift 4
  {
    RUN_PARAMS="benchmark=${app} threads=${threads}" print_log_header
    echo "#META app=${app}"
    echo "#META app_binary=${binary}"
    echo "---"
  } > "$logfile"
  ( "$@" ) >> "$logfile" 2>&1
  return "${PIPESTATUS[0]:-$?}"
}

for t in "${THREADS_ARR[@]}"; do
  # --- nbody (compute-bound) ---
  rundir="results/nbody/threads_${t}"
  mkdir -p "$rundir"
  echo ">> nbody hilos=${t}"
  run_and_log "${rundir}/threads_${t}.log" "nbody" "$t" "$NBODY_BIN" \
    env OMP_NUM_THREADS="$t" "$NBODY_BIN"
  [[ "$?" -ne 0 ]] && echo "run_apps: ADVERTENCIA — nbody t=${t} fallo, ver ${rundir}" >&2

  # --- stencil (memory-bound) ---
  rundir="results/stencil/threads_${t}"
  mkdir -p "$rundir"
  echo ">> stencil hilos=${t}"
  run_and_log "${rundir}/threads_${t}.log" "stencil" "$t" "$STENCIL_BIN" \
    env OMP_NUM_THREADS="$t" "$STENCIL_BIN"
  [[ "$?" -ne 0 ]] && echo "run_apps: ADVERTENCIA — stencil t=${t} fallo, ver ${rundir}" >&2
done

echo "run_apps: listo. logs en results/nbody/ y results/stencil/"
