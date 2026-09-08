#!/usr/bin/env bash
# Corre un barrido de xhpl variando el numero de procesos MPI.
# wrapper autonomo — NO toca run_sweep.sh (es de Luis, y HPL necesita
# mpirun -np + un HPL.dat por corrida en el CWD, cosas que run_sweep.sh
# no contempla).
#
# uso: ./scripts/run_hpl.sh
# variables opcionales: NPROCS_LIST="1 2 4 8", HPL_FRACTION, HPL_NB,
#                        MACHINE_ID, HOST_OS
set -uo pipefail  # sin -e: si un rank falla, seguimos con el resto del barrido

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

XHPL="${ROOT_DIR}/benchmarks/hpl-2.3/bin/Linux_OpenBLAS/xhpl"
if [[ ! -x "$XHPL" ]]; then
  echo "run_hpl: no existe $XHPL — corre antes ./scripts/build_hpl.sh" >&2
  exit 1
fi

DETECT_SPECS_QUIET=1 source "${ROOT_DIR}/scripts/detect_specs.sh"
source "${ROOT_DIR}/scripts/log_header.sh"

read -ra NPROCS_ARR <<< "${NPROCS_LIST:-1 2 4 8}"

for n in "${NPROCS_ARR[@]}"; do
  RUNDIR="results/hpl/np_${n}"
  mkdir -p "$RUNDIR"
  LOGFILE="${RUNDIR}/threads_${n}.log"

  echo ">> hpl con ${n} ranks mpi"

  python3 scripts/gen_hpl_dat.py --nprocs "$n" --out "${RUNDIR}/HPL.dat"

  {
    RUN_PARAMS="nprocs=${n}" print_log_header
    echo "#META hpl_binary=${XHPL}"
    echo "---"
  } > "$LOGFILE"

  # OMP_NUM_THREADS=1 explicito: hpl+openblas ya paraleliza via mpi ranks,
  # si dejamos openblas usar sus propios hilos ademas de los ranks,
  # nprocs*hilos supera los cores y los numeros colapsan.
  #
  # --bind-to: verificado en docker desktop/wsl2 que "--bind-to core"
  # falla con "failed to bind memory" (cgroups/numa del contenedor lo
  # bloquean) y cae a "none" solo. usamos "none" directo para no
  # ensuciar el log con ese warning; en la mac de referencia vale la
  # pena revalidar si "core" funciona limpio ahi y da mejor rendimiento.
  BIND_TO="${HPL_BIND_TO:-none}"
  (
    cd "$RUNDIR" || exit 1
    OMP_NUM_THREADS=1 mpirun --allow-run-as-root -np "$n" --bind-to "$BIND_TO" "$XHPL"
  ) >> "$LOGFILE" 2>&1
  status="${PIPESTATUS[0]:-$?}"

  if [[ "$status" -ne 0 ]]; then
    echo "run_hpl: ADVERTENCIA — np=${n} salio con status ${status}, ver ${LOGFILE}" >&2
  fi
done

echo "run_hpl: listo. logs en results/hpl/"
