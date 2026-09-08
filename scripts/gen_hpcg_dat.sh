#!/usr/bin/env bash
# Genera un hpcg.dat dinamico segun la ram detectada y el numero de
# procesos mpi con los que se va a correr xhpcg.
#
# nx/ny/nz son el SUBGRID LOCAL por proceso (no el problema global,
# verificado en ReadHpcgDat.cpp — hpcg reparte el dominio global entre
# ranks usando estos valores como el tamano que le toca a cada uno).
# minimo 16 por dimension (hpcg lo fuerza solo si el valor es invalido,
# pero lo respetamos desde el generador). multiplo de 8 por los 3
# coarsenings de multigrid (assert nxf%2==0 x3, GenerateCoarseProblem.cpp).
#
# uso: ./scripts/gen_hpcg_dat.sh --nprocs 4 --seconds 60 --out results/hpcg/.../hpcg.dat
set -euo pipefail

NPROCS=1
SECONDS_PER_RUN=60
OUT=""
FRACTION="${HPCG_FRACTION:-0.35}"
BYTES_PER_CELL="${HPCG_BYTES_PER_CELL:-1000}"  # aproximado, calibrar contra el reporte real de hpcg

while [[ $# -gt 0 ]]; do
  case "$1" in
    --nprocs) NPROCS="$2"; shift 2 ;;
    --seconds) SECONDS_PER_RUN="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --fraction) FRACTION="$2"; shift 2 ;;
    *) echo "gen_hpcg_dat: argumento desconocido: $1" >&2; exit 64 ;;
  esac
done

if [[ -z "$OUT" ]]; then
  echo "gen_hpcg_dat: falta --out" >&2
  exit 64
fi

if [[ -z "${MEM_TOTAL_KB:-}" ]]; then
  echo "gen_hpcg_dat: falta MEM_TOTAL_KB en el entorno — corre antes 'source scripts/detect_specs.sh'" >&2
  exit 1
fi

# ram utilizable repartida entre los ranks mpi que van a correr en esta maquina
mem_usable_kb=$(python3 -c "print(int(${MEM_TOTAL_KB} * ${FRACTION}))")
mem_usable_per_proc_kb=$(( mem_usable_kb / NPROCS ))
mem_usable_per_proc_bytes=$(( mem_usable_per_proc_kb * 1024 ))

# n = cubo tal que n^3 celdas * bytes_por_celda quepan en la ram por proceso
n_raw=$(python3 -c "print(int((${mem_usable_per_proc_bytes} / ${BYTES_PER_CELL}) ** (1/3)))")

# redondeamos hacia abajo a multiplo de 8, minimo 16
n=$(( (n_raw / 8) * 8 ))
if (( n < 16 )); then
  n=16
fi

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
HPCG benchmark input file (generado dinamicamente, no editar a mano)
Proyecto Caso 4 - Computacion Paralela y Distribuida UVG
${n} ${n} ${n}
${SECONDS_PER_RUN}
EOF

echo "gen_hpcg_dat: nx=ny=nz=${n} seconds=${SECONDS_PER_RUN} (nprocs=${NPROCS}, " \
     "mem_usable_per_proc_kb=${mem_usable_per_proc_kb}, bytes_per_cell=${BYTES_PER_CELL}) -> ${OUT}"
