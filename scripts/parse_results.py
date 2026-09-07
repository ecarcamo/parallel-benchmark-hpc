#!/usr/bin/env python3
"""Construye el CSV base a partir de los logs de los barridos.

Cada responsable debe añadir la expresión regular de la métrica de su benchmark
(GFLOPS, tiempo, ancho de banda, etc.) antes de consolidar resultados finales.
"""

import csv
import pathlib
import re

rows = []
for log_file in pathlib.Path("results").rglob("threads_*.log"):
    benchmark = log_file.parent.name
    threads = int(re.search(r"threads_(\d+)", log_file.name).group(1))
    text = log_file.read_text(errors="ignore")
    # TODO: implementar una regex específica para cada formato de salida.
    metric = None
    rows.append({"benchmark": benchmark, "threads": threads, "metric": metric})

pathlib.Path("results").mkdir(exist_ok=True)
with open("results/summary.csv", "w", newline="", encoding="utf-8") as output:
    writer = csv.DictWriter(output, fieldnames=["benchmark", "threads", "metric"])
    writer.writeheader()
    writer.writerows(rows)

print(f"Escritas {len(rows)} filas en results/summary.csv")
