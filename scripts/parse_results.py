#!/usr/bin/env python3
"""Construye el CSV consolidado a partir de los logs de los barridos.

despachamos por nombre de benchmark (carpeta results/<benchmark>/...) en
vez de un if/elif gigante: asi cuando alguien agregue un benchmark nuevo
(ej. npb) solo añade una funcion parse_xxx y una entrada en PARSERS, sin
tocar ni entender la logica de los demas.

estructura esperada en results/:
    results/stream/threads_<N>.log            (N = hilos openmp)
    results/hpl/np_<N>/threads_<N>.log         (N = ranks mpi)
    results/hpcg/np_<P>_threads_<T>[_validation]/threads_<T>.log

el benchmark se identifica por el primer segmento de la ruta relativa a
results/, no por el padre inmediato del log (hpl/hpcg anidan un
directorio np_<N> de por medio).
"""

import csv
import pathlib
import re

RESULTS_DIR = pathlib.Path("results")

# --- metadata comun: bloque #META al inicio de cada log ---

META_RE = re.compile(r"^#META\s+(\w+)=(.*)$")


def parse_meta(text: str) -> dict:
    meta = {}
    for line in text.splitlines():
        if not line.startswith("#META"):
            # el bloque meta va al inicio; en cuanto se acaba, cortamos
            if meta:
                break
            continue
        m = META_RE.match(line)
        if m:
            meta[m.group(1)] = m.group(2)
    return meta


# --- parser stream ---
# formato real verificado: "Copy:           43150.7     0.003644 ..."
STREAM_RE = re.compile(
    r"^(Copy|Scale|Add|Triad):\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*$",
    re.MULTILINE,
)


def parse_stream(text: str) -> dict:
    kernels = {}
    for m in STREAM_RE.finditer(text):
        kernels[m.group(1)] = float(m.group(2))
    valid = "Solution Validates" in text
    triad = kernels.get("Triad")
    return {
        "metric": triad,
        "metric_name": "Triad",
        "unit": "MB/s",
        "valid": "OK" if valid and triad is not None else "FAILED",
        "notes": ";".join(f"{k}={v}" for k, v in kernels.items()),
    }


# --- parser hpl ---
# formato real verificado: "WR11R2C4  4416  192  2  2  0.50  1.1523e+02"
# ojo: el tag W<R|C><digitos y letras variables> no tiene longitud fija
# (ej. WR11R2C4 vs el WR11C2R4 que se asumio al planear), por eso \S+
# en vez de \S{7}.
HPL_RE = re.compile(
    r"^(W[RC]\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.eE+-]+)",
    re.MULTILINE,
)
HPL_RESIDUAL_RE = re.compile(r"\.\.\.\.\.\.\s*(PASSED|FAILED)")


def parse_hpl(text: str) -> dict:
    matches = list(HPL_RE.finditer(text))
    if not matches:
        return {"metric": None, "metric_name": "Gflops", "unit": "Gflops",
                 "valid": "FAILED", "notes": "no se encontro linea de resultado"}
    # tomamos el ultimo match por si hay varias corridas en un solo log
    m = matches[-1]
    tag, n, nb, p, q, time_s, gflops = m.groups()
    residual = HPL_RESIDUAL_RE.search(text)
    valid = residual.group(1) if residual else "DESCONOCIDO"
    return {
        "metric": float(gflops),
        "metric_name": "Gflops",
        "unit": "Gflops",
        "valid": "OK" if valid == "PASSED" else "FAILED",
        "notes": f"tag={tag};N={n};NB={nb};P={p};Q={q};time_s={time_s};residual={valid}",
    }


# --- parser hpcg ---
# formato real verificado (Final Summary::... del .txt anexado al log):
# "Final Summary::HPCG result is VALID with a GFLOP/s rating of=3.17608"
HPCG_RE = re.compile(
    r"HPCG result is (VALID|INVALID) with a GFLOP/s rating of=([\d.eE+-]+)"
)
HPCG_EXEC_TIME_RE = re.compile(r"execution time \(sec\) is=([\d.eE+-]+)")
HPCG_OFFICIAL_MIN_RE = re.compile(r"must be at least=([\d.eE+-]+)")


def parse_hpcg(text: str) -> dict:
    m = HPCG_RE.search(text)
    if not m:
        return {"metric": None, "metric_name": "GFLOP/s", "unit": "GFLOP/s",
                 "valid": "FAILED", "notes": "no se encontro Final Summary"}
    valid, gflops = m.groups()
    exec_time = HPCG_EXEC_TIME_RE.search(text)
    official_min = HPCG_OFFICIAL_MIN_RE.search(text)
    notes = f"exec_time_s={exec_time.group(1) if exec_time else '?'}"
    if official_min and exec_time and float(exec_time.group(1)) < float(official_min.group(1)):
        notes += ";no_submission_valida_top500"
    return {
        "metric": float(gflops),
        "metric_name": "GFLOP/s",
        "unit": "GFLOP/s",
        "valid": "OK" if valid == "VALID" else "FAILED",
        "notes": notes,
    }


# --- parser npb (nas parallel benchmarks) ---
# NPB imprime al final un bloque "<KERNEL> Benchmark Completed." con lineas
# alineadas tipo "Mop/s total = 1234.56". La variante MPI reporta
# "Total processes" y la OpenMP "Total threads": de eso deducimos el modo,
# que es justo lo que queremos contrastar (comunicacion mpi vs openmp).
NPB_MOPS_RE = re.compile(r"Mop/s total\s*=\s*([\d.eE+-]+)")
NPB_KERNEL_RE = re.compile(r"^\s*(\w+)\s+Benchmark\s+Completed", re.MULTILINE)
NPB_CLASS_RE = re.compile(r"^\s*Class\s*=\s*(\S+)", re.MULTILINE)
NPB_TIME_RE = re.compile(r"Time in seconds\s*=\s*([\d.eE+-]+)")
NPB_VERIF_RE = re.compile(r"Verification\s*=\s*(SUCCESSFUL|UNSUCCESSFUL)")
NPB_PROCS_RE = re.compile(r"Total processes\s*=\s*(\d+)")
NPB_THREADS_RE = re.compile(r"Total threads\s*=\s*(\d+)")


def parse_npb(text: str) -> dict:
    m = NPB_MOPS_RE.search(text)
    if not m:
        return {"metric": None, "metric_name": "Mop/s", "unit": "Mop/s",
                "valid": "FAILED", "notes": "no se encontro 'Mop/s total'"}
    mops = float(m.group(1))
    kernel_m = NPB_KERNEL_RE.search(text)
    class_m = NPB_CLASS_RE.search(text)
    time_m = NPB_TIME_RE.search(text)
    verif_m = NPB_VERIF_RE.search(text)
    procs_m = NPB_PROCS_RE.search(text)
    threads_m = NPB_THREADS_RE.search(text)

    if procs_m:
        mode, parallelism = "mpi", procs_m.group(1)
    elif threads_m:
        mode, parallelism = "omp", threads_m.group(1)
    else:
        mode, parallelism = "?", "?"

    valid = "OK" if (verif_m and verif_m.group(1) == "SUCCESSFUL") else "FAILED"
    notes = (
        f"kernel={kernel_m.group(1) if kernel_m else '?'};"
        f"class={class_m.group(1) if class_m else '?'};"
        f"mode={mode};parallelism={parallelism};"
        f"time_s={time_m.group(1) if time_m else '?'}"
    )
    return {
        "metric": mops,
        "metric_name": "Mop/s",
        "unit": "Mop/s",
        "valid": valid,
        "notes": notes,
    }


# --- parser apps propias (nbody y stencil) ---
# ambas imprimen un bloque "key=value" entre "=== <APP> RESULT ===" y su
# "=== END ... ===". Leemos los pares directamente: es nuestro formato, no
# hay que adivinar regex de terceros como en hpl/hpcg.
APP_KV_RE = re.compile(r"^(\w+)=(\S+)$", re.MULTILINE)


def _parse_app(text: str, expected_app: str) -> dict:
    kv = {}
    for m in APP_KV_RE.finditer(text):
        kv[m.group(1)] = m.group(2)
    gflops = kv.get("gflops")
    if gflops is None:
        return {"metric": None, "metric_name": "GFLOP/s", "unit": "GFLOP/s",
                "valid": "FAILED", "notes": f"no se encontro bloque {expected_app} RESULT"}
    # notas: guardamos intensidad aritmetica (eje X del Roofline), tiempo y
    # el tamano del problema, que es lo que consume analysis/roofline.py.
    parts = [f"bound={kv.get('bound', '?')}",
             f"ai={kv.get('arithmetic_intensity', '?')}",
             f"time_s={kv.get('time_s', '?')}"]
    if "bandwidth_gbps" in kv:
        parts.append(f"bandwidth_gbps={kv['bandwidth_gbps']}")
    if "n_bodies" in kv:
        parts.append(f"n_bodies={kv['n_bodies']};steps={kv.get('steps', '?')}")
    if "grid_n" in kv:
        parts.append(f"grid_n={kv['grid_n']};steps={kv.get('steps', '?')}")
    return {
        "metric": float(gflops),
        "metric_name": "GFLOP/s",
        "unit": "GFLOP/s",
        "valid": "OK",
        "notes": ";".join(parts),
    }


def parse_nbody(text: str) -> dict:
    return _parse_app(text, "NBODY")


def parse_stencil(text: str) -> dict:
    return _parse_app(text, "STENCIL")


PARSERS = {
    "stream": parse_stream,
    "hpl": parse_hpl,
    "hpcg": parse_hpcg,
    "npb": parse_npb,
    "nbody": parse_nbody,
    "stencil": parse_stencil,
}


def extract_benchmark_name(log_file: pathlib.Path) -> str:
    """primer segmento de la ruta relativa a results/, ej.
    results/hpcg/np_4_threads_2/threads_2.log -> 'hpcg'."""
    rel = log_file.relative_to(RESULTS_DIR)
    return rel.parts[0]


def extract_procs(log_file: pathlib.Path) -> int | None:
    """de carpetas tipo np_<N> o np_<P>_threads_<T>, sacamos el valor de np_."""
    m = re.search(r"np_(\d+)", str(log_file))
    return int(m.group(1)) if m else None


def main() -> None:
    rows = []
    for log_file in sorted(RESULTS_DIR.rglob("threads_*.log")):
        benchmark = extract_benchmark_name(log_file)
        threads_m = re.search(r"threads_(\d+)", log_file.name)
        threads = int(threads_m.group(1)) if threads_m else None
        procs = extract_procs(log_file)

        text = log_file.read_text(errors="ignore")
        meta = parse_meta(text)

        parser = PARSERS.get(benchmark)
        if parser is None:
            print(f"parse_results: sin parser para benchmark '{benchmark}' "
                  f"({log_file}) — se omite la metrica, TODO agregar en PARSERS")
            result = {"metric": None, "metric_name": None, "unit": None,
                      "valid": "SIN_PARSER", "notes": ""}
        else:
            result = parser(text)

        rows.append({
            "benchmark": benchmark,
            "threads": threads,
            "procs": procs,
            "metric": result.get("metric"),
            "metric_name": result.get("metric_name"),
            "unit": result.get("unit"),
            "valid": result.get("valid"),
            "machine": meta.get("machine_id", "desconocido"),
            "notes": result.get("notes", ""),
        })

    RESULTS_DIR.mkdir(exist_ok=True)
    fieldnames = ["benchmark", "threads", "procs", "metric", "metric_name",
                  "unit", "valid", "machine", "notes"]
    with open(RESULTS_DIR / "summary.csv", "w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Escritas {len(rows)} filas en results/summary.csv")


if __name__ == "__main__":
    main()
