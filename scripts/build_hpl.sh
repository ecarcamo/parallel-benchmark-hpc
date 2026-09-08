#!/usr/bin/env bash
# Descomprime (si hace falta) y compila HPL 2.3 contra openmpi + openblas.
# idempotente: si ya existe el binario, no vuelve a compilar salvo --force.
#
# uso: ./scripts/build_hpl.sh [--force]
# salida: benchmarks/hpl-2.3/bin/Linux_OpenBLAS/xhpl
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="${ROOT_DIR}/benchmarks"
HPL_DIR="${BENCH_DIR}/hpl-2.3"
TARBALL="${BENCH_DIR}/hpl-2.3.tar.gz"
ARCH="Linux_OpenBLAS"
BIN="${HPL_DIR}/bin/${ARCH}/xhpl"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

if [[ -x "$BIN" && "$FORCE" -eq 0 ]]; then
  echo "build_hpl: ya existe $BIN (usa --force para recompilar)"
  exit 0
fi

if [[ ! -f "$TARBALL" ]]; then
  echo "build_hpl: no existe $TARBALL — corre antes ./scripts/fetch_benchmarks.sh" >&2
  exit 1
fi

if [[ ! -d "$HPL_DIR" ]]; then
  echo "build_hpl: descomprimiendo $TARBALL"
  tar xzf "$TARBALL" -C "$BENCH_DIR"
fi

MAKE_SRC="${ROOT_DIR}/configs/Make.Linux_OpenBLAS"
if [[ ! -f "$MAKE_SRC" ]]; then
  echo "build_hpl: no existe $MAKE_SRC" >&2
  exit 1
fi
# ojo: HPL busca "Make.<arch>" en la RAIZ del arbol fuente (Make.top hace
# `include Make.$(arch)`), setup/ es solo el repositorio de plantillas de
# ejemplo — copiar ahi no sirve, hay que copiar a la raiz. Verificado
# corriendo el build real.
cp "$MAKE_SRC" "${HPL_DIR}/Make.${ARCH}"

echo "build_hpl: compilando (arch=${ARCH}, TOPdir=${HPL_DIR})"
if [[ "$FORCE" -eq 1 ]]; then
  make -C "$HPL_DIR" arch="$ARCH" HPL_TOPDIR="$HPL_DIR" clean_arch_all || true
fi
make -C "$HPL_DIR" arch="$ARCH" HPL_TOPDIR="$HPL_DIR"

if [[ ! -x "$BIN" ]]; then
  echo "build_hpl: la compilacion termino pero no aparece $BIN — revisar salida de make" >&2
  exit 1
fi

echo "build_hpl: listo -> $BIN"
