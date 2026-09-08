#!/usr/bin/env bash
# Descomprime (si hace falta) y compila las NAS Parallel Benchmarks 3.4.3
# en sus DOS variantes: OpenMP (memoria compartida) y MPI (memoria
# distribuida). Correr el mismo kernel en ambas es lo que nos deja medir
# el overhead de comunicacion MPI vs OpenMP, que es el punto de NPB como
# proxy de SPEC (ver docs/spec-investigacion.md).
#
# idempotente: si el binario ya existe, no recompila salvo --force.
#
# uso: ./scripts/build_npb.sh [--force]
# variables opcionales:
#   NPB_KERNELS      kernels a compilar (default "cg ep")
#   NPB_CLASS        clase / tamano del problema (default "A")
#
# salidas (en NPB 3.4 el nprocs de MPI es de RUNTIME, no compile-time:
# un solo binario .x por kernel/clase que acepta cualquier -np):
#   benchmarks/NPB3.4.3/NPB3.4-OMP/bin/<kernel>.<CLASS>.x
#   benchmarks/NPB3.4.3/NPB3.4-MPI/bin/<kernel>.<CLASS>.x
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="${ROOT_DIR}/benchmarks"
TARBALL="${BENCH_DIR}/NPB3.4.3.tar.gz"
NPB_DIR="${BENCH_DIR}/NPB3.4.3"
OMP_DIR="${NPB_DIR}/NPB3.4-OMP"
MPI_DIR="${NPB_DIR}/NPB3.4-MPI"

KERNELS="${NPB_KERNELS:-cg ep}"
CLASS="${NPB_CLASS:-A}"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

if [[ ! -f "$TARBALL" ]]; then
  echo "build_npb: no existe $TARBALL — corre antes ./scripts/fetch_benchmarks.sh" >&2
  exit 1
fi

if [[ ! -d "$NPB_DIR" ]]; then
  echo "build_npb: descomprimiendo $TARBALL"
  tar xzf "$TARBALL" -C "$BENCH_DIR"
fi

# NPB necesita config/make.def y config/suite.def presentes antes de make.
# suite.def no lo usamos (compilamos target por target), pero make.def si:
# copiamos NUESTRO make.def para cada variante desde configs/.
cp "${ROOT_DIR}/configs/npb_make.def.omp" "${OMP_DIR}/config/make.def"
cp "${ROOT_DIR}/configs/npb_make.def.mpi" "${MPI_DIR}/config/make.def"

# --- OpenMP: los hilos son runtime (OMP_NUM_THREADS), un solo binario ---
# ojo: EP/CG/FT/... requieren en MPI un nprocs potencia de 2; en OMP no
# hay esa restriccion porque el paralelismo es por hilos, no por ranks.
build_omp() {
  local kernel_uc="$1"                 # nombre en mayuscula para el make target
  local kernel_lc="${kernel_uc,,}"
  local bin="${OMP_DIR}/bin/${kernel_lc}.${CLASS}.x"
  if [[ -x "$bin" && "$FORCE" -eq 0 ]]; then
    echo "build_npb[omp]: ya existe $(basename "$bin") (usa --force para recompilar)"
    return 0
  fi
  echo "build_npb[omp]: make ${kernel_uc} CLASS=${CLASS}"
  make -C "$OMP_DIR" "$kernel_uc" CLASS="$CLASS" >/dev/null
  [[ -x "$bin" ]] || { echo "build_npb[omp]: no aparecio $bin — revisar make" >&2; return 1; }
}

# --- MPI: en NPB 3.4 el nprocs es runtime, un solo binario .x por kernel ---
# (verificado: `make CG CLASS=A` genera bin/cg.A.x y mpirun -np N lo corre
# con N procesos; los kernels tipo CG exigen que N sea potencia de 2, se
# valida en runtime via get_active_nprocs).
build_mpi() {
  local kernel_uc="$1"
  local kernel_lc="${kernel_uc,,}"
  local bin="${MPI_DIR}/bin/${kernel_lc}.${CLASS}.x"
  if [[ -x "$bin" && "$FORCE" -eq 0 ]]; then
    echo "build_npb[mpi]: ya existe $(basename "$bin") (usa --force para recompilar)"
    return 0
  fi
  echo "build_npb[mpi]: make ${kernel_uc} CLASS=${CLASS}"
  make -C "$MPI_DIR" "$kernel_uc" CLASS="$CLASS" >/dev/null
  [[ -x "$bin" ]] || { echo "build_npb[mpi]: no aparecio $bin — revisar make" >&2; return 1; }
}

for kernel in $KERNELS; do
  kernel_uc="${kernel^^}"
  build_omp "$kernel_uc"
  build_mpi "$kernel_uc"
done

echo "build_npb: listo."
echo "  omp -> ${OMP_DIR}/bin/"
echo "  mpi -> ${MPI_DIR}/bin/"
