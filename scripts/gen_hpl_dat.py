#!/usr/bin/env python3
"""Genera un HPL.dat dinamico segun la maquina detectada.

nada de N/NB/P/Q fijos: N sale de la ram detectada, P/Q del numero de
ranks mpi que le pasemos. asi el mismo generador sirve en cualquier
maquina sin tocar codigo.

uso:
    python3 scripts/gen_hpl_dat.py --nprocs 4 --out results/hpl/np_4/HPL.dat
    python3 scripts/gen_hpl_dat.py --nprocs 4 --fraction 0.5 --nb 192

variables de entorno esperadas (las pone detect_specs.sh):
    MEM_TOTAL_KB — requerida para calcular N.
"""
import argparse
import math
import os
import pathlib
import sys


def compute_n(mem_total_kb: int, fraction: float, nb: int) -> int:
    """N tal que la matriz N*N de doubles (8 bytes) ocupe ~fraction de la ram."""
    mem_bytes = mem_total_kb * 1024
    n_raw = math.sqrt(fraction * mem_bytes / 8)
    # redondeamos hacia abajo a multiplo de nb — sobrestimar revienta la ram
    n = int(n_raw // nb) * nb
    return max(n, nb)  # nunca menos de un bloque


def compute_pq(nprocs: int) -> tuple[int, int]:
    """grid P x Q lo mas cuadrado posible, P <= Q, P*Q == nprocs."""
    p = int(math.sqrt(nprocs))
    while p > 1 and nprocs % p != 0:
        p -= 1
    q = nprocs // p
    return p, q


def render_hpl_dat(n: int, nb: int, p: int, q: int) -> str:
    """31 lineas, formato posicional estricto de HPL. reducido a una sola
    configuracion tuneada (no el producto cruzado del archivo de referencia,
    que correria decenas de variantes por invocacion)."""
    lines = [
        "HPLinpack benchmark input file (generado dinamicamente, no editar a mano)",
        "Innovative Computing Laboratory, University of Tennessee",
        "HPL.out      output file name (if any)",
        "6            device out (6=stdout,7=stderr,file)   <- debe ser 6",
        "1            # of problems sizes (N)",
        f"{n}          Ns",
        "1            # of NBs",
        f"{nb}         NBs",
        "0            PMAP process mapping (0=Row-,1=Column-major)",
        "1            # of process grids (P x Q)",
        f"{p}            Ps",
        f"{q}            Qs",
        "16.0         threshold",
        "1            # of panel fact",
        "1            PFACTs (0=left, 1=Crout, 2=Right)",
        "1            # of recursive stopping criterium",
        "4            NBMINs (>= 1)",
        "1            # of panels in recursion",
        "2            NDIVs",
        "1            # of recursive panel fact.",
        "2            RFACTs (0=left, 1=Crout, 2=Right)",
        "1            # of broadcast",
        "1            BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)",
        "1            # of lookahead depth",
        "1            DEPTHs (>=0)",
        "2            SWAP (0=bin-exch,1=long,2=mix)",
        "64           swapping threshold",
        "0            L1 in (0=transposed,1=no-transposed) form",
        "0            U  in (0=transposed,1=no-transposed) form",
        "1            Equilibration (0=no,1=yes)",
        "8            memory alignment in double (> 0)",
    ]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nprocs", type=int, required=True,
                         help="numero de ranks mpi con los que se va a correr xhpl")
    parser.add_argument("--fraction", type=float, default=float(os.environ.get("HPL_FRACTION", 0.55)),
                         help="fraccion de la ram total a usar para dimensionar N (default 0.55, "
                              "mas conservador que el 0.8 clasico porque en un contenedor "
                              "el runtime mpi y los buffers de openblas tambien compiten por ram)")
    parser.add_argument("--nb", type=int, default=int(os.environ.get("HPL_NB", 192)),
                         help="block size (default 192, rango util 128-256)")
    parser.add_argument("--out", required=True, help="ruta de salida del HPL.dat")
    args = parser.parse_args()

    mem_total_kb = os.environ.get("MEM_TOTAL_KB")
    if not mem_total_kb:
        print("gen_hpl_dat: falta MEM_TOTAL_KB en el entorno — corre antes "
              "`source scripts/detect_specs.sh`", file=sys.stderr)
        return 1
    mem_total_kb = int(mem_total_kb)

    n = compute_n(mem_total_kb, args.fraction, args.nb)
    p, q = compute_pq(args.nprocs)

    out_path = pathlib.Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render_hpl_dat(n, args.nb, p, q), encoding="utf-8")

    print(f"gen_hpl_dat: N={n} NB={args.nb} P={p} Q={q} (nprocs={args.nprocs}, "
          f"fraction={args.fraction}, mem_total_kb={mem_total_kb}) -> {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
