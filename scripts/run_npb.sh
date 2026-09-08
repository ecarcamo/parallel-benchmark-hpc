#!/usr/bin/env bash
# Corre las NAS Parallel Benchmarks en sus dos variantes sobre el MISMO
# kernel: OpenMP barriendo hilos y MPI barriendo procesos. La gracia es
# comparar el mismo algoritmo bajo memoria compartida vs. distribuida y
# aislar el overhead de comunicacion (cuello de botella asignado a Nico).
#
# wrapper autonomo — NO toca run_sweep.sh: MPI necesita mpirun -np y
# binarios distintos por nprocs, cosas que run_sweep.sh no contempla
# (mismo criterio que run_hpl.sh / run_hpcg.sh).
#
# uso: ./scripts/run_npb.sh
# variables opcionales:
#   NPB_KERNELS         kernels a correr (default "cg ep")
#   NPB_CLASS           clase compilada (default "A") — debe coincidir con build_npb.sh
#   NPB_THREADS_LIST    barrido de hilos OpenMP (default "1 2 4 8")
#   NPB_NPROCS_LIST     barrido de procesos MPI (default "1 2 4 8")
#   NPB_BIND_TO         politica --bind-to de mpirun (default "none", ver run_hpl.sh)
set -uo pipefail  # sin -e: si una corrida falla, seguimos con el resto del barrido

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NPB_DIR="${ROOT_DIR}/benchmarks/NPB3.4.3"
OMP_BIN_DIR="${NPB_DIR}/NPB3.4-OMP/bin"
MPI_BIN_DIR="${NPB_DIR}/NPB3.4-MPI/bin"

if [[ ! -d "$NPB_DIR" ]]; then
  echo "run_npb: no existe $NPB_DIR — corre antes ./scripts/build_npb.sh" >&2
  exit 1
fi

DETECT_SPECS_QUIET=1 source "${ROOT_DIR}/scripts/detect_specs.sh"
source "${ROOT_DIR}/scripts/log_header.sh"

KERNELS="${NPB_KERNELS:-cg ep}"
CLASS="${NPB_CLASS:-A}"
read -ra THREADS_ARR <<< "${NPB_THREADS_LIST:-1 2 4 8}"
read -ra NPROCS_ARR  <<< "${NPB_NPROCS_LIST:-1 2 4 8}"
BIND_TO="${NPB_BIND_TO:-none}"

# escribe el header #META + la salida del binario en un solo log, para que
# parse_results.py solo tenga que mirar un archivo (mismo patron que hpcg).
run_and_log() {
  local logfile="$1" mode="$2" parallelism="$3" binary="$4"; shift 4
  {
    RUN_PARAMS="benchmark=npb kernel=${KERNEL} class=${CLASS} mode=${mode} parallelism=${parallelism}" print_log_header
    echo "#META npb_kernel=${KERNEL}"
    echo "#META npb_class=${CLASS}"
    echo "#META npb_mode=${mode}"
    echo "#META npb_binary=${binary}"
    echo "---"
  } > "$logfile"
  ( "$@" ) >> "$logfile" 2>&1
  return "${PIPESTATUS[0]:-$?}"
}

for kernel in $KERNELS; do
  KERNEL="$kernel"
  kernel_lc="${kernel,,}"

  # --- variante OpenMP: hilos runtime, un solo binario <kernel>.<class>.x ---
  omp_bin="${OMP_BIN_DIR}/${kernel_lc}.${CLASS}.x"
  if [[ -x "$omp_bin" ]]; then
    for t in "${THREADS_ARR[@]}"; do
      rundir="results/npb/${kernel_lc}_${CLASS}_omp_threads_${t}"
      mkdir -p "$rundir"
      echo ">> npb ${kernel_lc} omp hilos=${t}"
      OMP_NUM_THREADS="$t" run_and_log \
        "${rundir}/threads_${t}.log" "omp" "$t" "$omp_bin" \
        env OMP_NUM_THREADS="$t" "$omp_bin"
      [[ "$?" -ne 0 ]] && echo "run_npb: ADVERTENCIA — ${kernel_lc} omp t=${t} fallo, ver ${rundir}" >&2
    done
  else
    echo "run_npb: falta $omp_bin — se omite omp de ${kernel_lc} (corre build_npb.sh)" >&2
  fi

  # --- variante MPI: un solo binario .x, el -np se elige en runtime ---
  mpi_bin="${MPI_BIN_DIR}/${kernel_lc}.${CLASS}.x"
  for np in "${NPROCS_ARR[@]}"; do
    if [[ ! -x "$mpi_bin" ]]; then
      echo "run_npb: falta $mpi_bin — se omite mpi de ${kernel_lc} (corre build_npb.sh)" >&2
      break
    fi
    rundir="results/npb/${kernel_lc}_${CLASS}_mpi_np_${np}_threads_1"
    mkdir -p "$rundir"
    echo ">> npb ${kernel_lc} mpi np=${np}"
    # OMP_NUM_THREADS=1: la variante MPI no usa openmp; lo fijamos para que
    # ninguna libreria abra hilos extra y contamine el conteo de cores.
    OMP_NUM_THREADS=1 run_and_log \
      "${rundir}/threads_1.log" "mpi" "$np" "$mpi_bin" \
      mpirun --allow-run-as-root -np "$np" --bind-to "$BIND_TO" "$mpi_bin"
    [[ "$?" -ne 0 ]] && echo "run_npb: ADVERTENCIA — ${kernel_lc} mpi np=${np} fallo, ver ${rundir}" >&2
  done
done

echo "run_npb: listo. logs en results/npb/"
