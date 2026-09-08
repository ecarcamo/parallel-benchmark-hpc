#!/usr/bin/env bash
# Corre un barrido de xhpcg a CARGA CONSTANTE: procs x hilos ~= cores
# fisicos, variando el reparto entre mpi y openmp. eso aisla el efecto
# de "como repartir el paralelismo" que es la pregunta que el proyecto
# quiere contestar (hpcg es hibrido mpi+openmp).
#
# wrapper autonomo — NO toca run_sweep.sh, por lo mismo que run_hpl.sh:
# hpcg necesita mpirun -np + hpcg.dat en el cwd + aislar los archivos
# de salida con timestamp que el propio hpcg genera.
#
# uso: ./scripts/run_hpcg.sh
# variables opcionales: HPCG_SECONDS_SWEEP (default 60),
#                        HPCG_SECONDS_VALIDATION (default 300),
#                        HPCG_COMBOS (default se arma desde CORES_PHYSICAL)
set -uo pipefail  # sin -e: si una combinacion falla, seguimos con el resto

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

XHPCG="${ROOT_DIR}/benchmarks/hpcg/build/bin/xhpcg"
if [[ ! -x "$XHPCG" ]]; then
  echo "run_hpcg: no existe $XHPCG — corre antes ./scripts/build_hpcg.sh" >&2
  exit 1
fi

DETECT_SPECS_QUIET=1 source "${ROOT_DIR}/scripts/detect_specs.sh"
source "${ROOT_DIR}/scripts/log_header.sh"

SECONDS_SWEEP="${HPCG_SECONDS_SWEEP:-60}"
SECONDS_VALIDATION="${HPCG_SECONDS_VALIDATION:-300}"
CORES="${CORES_PHYSICAL:-1}"

# combos "procs:hilos" a carga constante (procs*hilos ~= cores fisicos).
# default: full-mpi, mitad/mitad, cuarto/cuarto, full-openmp.
if [[ -z "${HPCG_COMBOS:-}" ]]; then
  declare -a combos=("${CORES}:1")
  half=$(( CORES / 2 )); (( half >= 1 )) && combos+=("${half}:2")
  quarter=$(( CORES / 4 )); (( quarter >= 1 )) && combos+=("${quarter}:4")
  combos+=("1:${CORES}")
else
  read -ra combos <<< "$HPCG_COMBOS"
fi

run_one() {
  local procs="$1" threads="$2" seconds="$3" label="$4"
  local rundir="results/hpcg/np_${procs}_threads_${threads}${label:+_$label}"
  mkdir -p "$rundir"
  local logfile="${rundir}/threads_${threads}.log"

  echo ">> hpcg procs=${procs} hilos=${threads} seconds=${seconds} ${label}"

  ./scripts/gen_hpcg_dat.sh --nprocs "$procs" --seconds "$seconds" --out "${rundir}/hpcg.dat"

  {
    RUN_PARAMS="nprocs=${procs} threads=${threads} seconds=${seconds}" print_log_header
    echo "#META hpcg_binary=${XHPCG}"
    echo "---"
  } > "$logfile"

  (
    cd "$rundir" || exit 1
    OMP_NUM_THREADS="$threads" mpirun --allow-run-as-root -np "$procs" --bind-to "${HPCG_BIND_TO:-none}" "$XHPCG"
  ) >> "$logfile" 2>&1
  local status="${PIPESTATUS[0]:-$?}"

  # el .txt final queda en el mismo rundir (hpcg escribe en su cwd);
  # lo anexamos al log para que el parser solo tenga que mirar un archivo.
  local summary
  summary="$(ls "${rundir}"/HPCG-Benchmark_*.txt 2>/dev/null | head -n1)"
  if [[ -n "$summary" ]]; then
    {
      echo "--- HPCG-Benchmark summary ---"
      cat "$summary"
    } >> "$logfile"
  fi

  if [[ "$status" -ne 0 ]]; then
    echo "run_hpcg: ADVERTENCIA — procs=${procs} threads=${threads} salio con status ${status}, ver ${logfile}" >&2
  fi
}

for combo in "${combos[@]}"; do
  procs="${combo%%:*}"
  threads="${combo##*:}"
  run_one "$procs" "$threads" "$SECONDS_SWEEP" ""
done

# una corrida de validacion mas larga (no submission-valida para TOP500,
# que exige 1800s, pero mas cerca del estandar que el barrido rapido).
# usa el combo mas balanceado (el segundo de la lista si existe, si no el primero).
validation_combo="${combos[1]:-${combos[0]}}"
procs="${validation_combo%%:*}"
threads="${validation_combo##*:}"
run_one "$procs" "$threads" "$SECONDS_VALIDATION" "validation"

echo "run_hpcg: listo. logs en results/hpcg/"
