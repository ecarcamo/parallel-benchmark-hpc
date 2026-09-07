#!/usr/bin/env bash
# Descarga únicamente las fuentes; cada responsable decide su compilación y tuning.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="${ROOT_DIR}/benchmarks"
mkdir -p "$BENCH_DIR"

download() {
  local url="$1" output="$2"
  if [[ -e "$output" ]]; then
    echo "Ya existe: $output"
  else
    wget --https-only --progress=dot:giga -O "$output" "$url"
  fi
}

if [[ ! -d "$BENCH_DIR/hpcg/.git" ]]; then
  git clone --depth 1 https://github.com/hpcg-benchmark/hpcg.git "$BENCH_DIR/hpcg"
else
  echo "Ya existe: $BENCH_DIR/hpcg"
fi

download "https://www.netlib.org/benchmark/hpl/hpl-2.3.tar.gz" \
  "$BENCH_DIR/hpl-2.3.tar.gz"
download "https://www.nas.nasa.gov/assets/npb/NPB3.4.3.tar.gz" \
  "$BENCH_DIR/NPB3.4.3.tar.gz"
download "https://www.cs.virginia.edu/stream/FTP/Code/stream.c" \
  "$BENCH_DIR/stream.c"

echo "Fuentes descargadas en $BENCH_DIR"
