#!/usr/bin/env bash
# Compila HPCG (ya clonado por fetch_benchmarks.sh) contra openmpi + openmp.
# idempotente: si ya existe el binario, no vuelve a compilar salvo --force.
#
# uso: ./scripts/build_hpcg.sh [--force]
# salida: benchmarks/hpcg/build/bin/xhpcg
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HPCG_SRC="${ROOT_DIR}/benchmarks/hpcg"
BUILD_DIR="${HPCG_SRC}/build"
ARCH="uvg"
BIN="${BUILD_DIR}/bin/xhpcg"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

if [[ -x "$BIN" && "$FORCE" -eq 0 ]]; then
  echo "build_hpcg: ya existe $BIN (usa --force para recompilar)"
  exit 0
fi

if [[ ! -d "$HPCG_SRC" ]]; then
  echo "build_hpcg: no existe $HPCG_SRC — corre antes ./scripts/fetch_benchmarks.sh" >&2
  exit 1
fi

MAKE_SRC="${ROOT_DIR}/configs/Make.${ARCH}"
if [[ ! -f "$MAKE_SRC" ]]; then
  echo "build_hpcg: no existe $MAKE_SRC" >&2
  exit 1
fi

# hpcg exige que "setup/Make.<arch>" ya exista en el arbol fuente ANTES
# de correr configure (configure lo copia desde ahi al build dir).
cp "$MAKE_SRC" "${HPCG_SRC}/setup/Make.${ARCH}"

if [[ "$FORCE" -eq 1 && -d "$BUILD_DIR" ]]; then
  rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

echo "build_hpcg: configurando (arch=${ARCH})"
(
  cd "$BUILD_DIR"
  "${HPCG_SRC}/configure" "$ARCH"
  make
)

if [[ ! -x "$BIN" ]]; then
  echo "build_hpcg: la compilacion termino pero no aparece $BIN — revisar salida de make" >&2
  exit 1
fi

echo "build_hpcg: listo -> $BIN"
