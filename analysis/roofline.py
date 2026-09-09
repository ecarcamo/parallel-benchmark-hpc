#!/usr/bin/env python3
"""Analisis Roofline y graficas de la presentacion.

Lee results/summary.csv (el CSV consolidado por scripts/parse_results.py) y
genera en analysis/:

  1. roofline.png        -- el modelo Roofline que une TODOS los benchmarks
  2. scaling_apps.png    -- speedup vs hilos: nbody (compute) vs stencil (memory)
  3. hpl_vs_hpcg.png     -- la brecha: pico (HPL) vs carga realista (HPCG)
  4. npb_omp_vs_mpi.png  -- overhead de comunicacion: mismo kernel OMP vs MPI

La idea central del proyecto (el "efecto WOW"): el numero de las noticias
(HPL, punta de flops) NO es el que se ve en aplicaciones reales (HPCG,
memory-bound). El Roofline explica visualmente por que: cada carga choca
contra un techo distinto — computo o ancho de banda.

Marco teorico: Williams, Waterman y Patterson (2009), "Roofline: An
Insightful Visual Performance Model for Multicore Architectures", CACM 52(4).

uso: python3 analysis/roofline.py
"""

import csv
import pathlib
import re

import matplotlib

matplotlib.use("Agg")  # sin display, guardamos a PNG
import matplotlib.pyplot as plt

ROOT = pathlib.Path(__file__).resolve().parent.parent
CSV = ROOT / "results" / "summary.csv"
OUT = ROOT / "analysis"

# --- paleta consistente (buena en proyector) ---
C_COMPUTE = "#d1495b"   # rojo — compute-bound
C_MEMORY = "#2e86ab"    # azul — memory-bound
C_CEIL = "#3d3d3d"      # gris techos
C_RIDGE = "#e0a458"     # ambar punto de quiebre
C_OMP = "#2e86ab"
C_MPI = "#d1495b"

# Ancho de banda PICO TEORICO de la maquina de referencia (Apple M4 Pro):
# 273 GB/s, dato OFICIAL de Apple (newsroom, oct. 2024). Lo usamos como techo
# de memoria del Roofline porque es una fuente INDEPENDIENTE de nuestros
# kernels: asi el punto memory-bound (stencil) NO cae sobre el techo "por
# construccion" — se ve la fraccion real del pico que alcanza (~58 %).
# La vieja corrida de STREAM (32.6 GB/s, machine "desconocido") no es
# representativa del M4 Pro (memoria unificada) y por eso no se usa como techo.
PEAK_BW_SPEC_GBPS = 273.0

plt.rcParams.update({
    "figure.dpi": 130,
    "font.size": 12,
    "axes.grid": True,
    "grid.alpha": 0.25,
    "axes.spines.top": False,
    "axes.spines.right": False,
})


def note_get(notes: str, key: str):
    """saca un campo key=valor de la columna notes (separada por ';')."""
    m = re.search(rf"(?:^|;){re.escape(key)}=([^;]+)", notes or "")
    return m.group(1) if m else None


def load_rows():
    with open(CSV, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def to_float(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


# ---------------------------------------------------------------------------
# extraccion de metricas clave desde el CSV
# ---------------------------------------------------------------------------

def best_metric(rows, benchmark):
    """mejor (max) metrica de un benchmark a traves de todos los hilos."""
    vals = [to_float(r["metric"]) for r in rows
            if r["benchmark"] == benchmark and to_float(r["metric"]) is not None]
    return max(vals) if vals else None


def stream_peak_gbps(rows):
    """STREAM reporta Triad en MB/s; el pico -> GB/s (ancho de banda techo)."""
    peak_mbs = best_metric(rows, "stream")
    return peak_mbs / 1000.0 if peak_mbs else None


def hpl_peak_gflops(rows):
    return best_metric(rows, "hpl")


def hpl_intensity(rows):
    """AI geometrica de HPL: hace ~(2/3)N^3 flops sobre ~N^2*8 bytes de
    datos, asi que AI ~= N/12 flop/byte. Sacamos N del campo notes."""
    for r in rows:
        if r["benchmark"] == "hpl":
            n = note_get(r["notes"], "N")
            if n:
                return float(n) / 12.0
    return None


def app_points(rows, app):
    """puntos (hilos -> gflops, ai) de una app propia (nbody/stencil)."""
    pts = {}
    for r in rows:
        if r["benchmark"] != app:
            continue
        t = to_float(r["threads"])
        g = to_float(r["metric"])
        ai = to_float(note_get(r["notes"], "ai"))
        bw = to_float(note_get(r["notes"], "bandwidth_gbps"))
        if t is not None and g is not None:
            pts[int(t)] = {"gflops": g, "ai": ai, "bw": bw}
    return pts


# ---------------------------------------------------------------------------
# 1. Roofline
# ---------------------------------------------------------------------------

def app_peak_bandwidth(rows):
    """maximo ancho de banda medido por el stencil (GB/s) en el barrido."""
    bws = [to_float(note_get(r["notes"], "bandwidth_gbps"))
           for r in rows if r["benchmark"] == "stencil"]
    bws = [b for b in bws if b]
    return max(bws) if bws else None


def plot_roofline(rows):
    # Techo de ANCHO DE BANDA: pico teorico publicado del M4 Pro (fuente
    # INDEPENDIENTE, ver PEAK_BW_SPEC_GBPS). Evita la circularidad de usar el
    # ancho de banda del propio stencil como techo. El stencil queda POR
    # DEBAJO, mostrando que fraccion del pico sostiene (~58 %).
    peak_bw = PEAK_BW_SPEC_GBPS
    stencil_bw = app_peak_bandwidth(rows)  # solo para reportar en consola

    # Techo de COMPUTO = max(HPL, nbody) medido. nbody puede superar a HPL por
    # ser un kernel mas simple; tomamos el mayor como pico empirico medido.
    hpl = hpl_peak_gflops(rows)
    nbody_pts = app_points(rows, "nbody")
    nbody_peak = max((p["gflops"] for p in nbody_pts.values()), default=None)
    peak_flops = max([g for g in (hpl, nbody_peak) if g] or [0]) or None

    if not peak_flops:
        print("roofline: faltan datos de computo, no se dibuja")
        return

    ridge = peak_flops / peak_bw  # AI del punto de quiebre (flop/byte)

    # Formato panoramico: la grafica ocupa una escena 16:10 sin cortar ejes.
    fig, ax = plt.subplots(figsize=(11.8, 5.35))
    ax.set_xscale("log")
    ax.set_yscale("log")

    ai_min, ai_max = 0.05, 1e4
    xs_mem = [ai_min, ridge]
    ys_mem = [peak_bw * ai_min, peak_bw * ridge]     # recta ancho de banda
    xs_cmp = [ridge, ai_max]
    ys_cmp = [peak_flops, peak_flops]                # techo de computo

    ax.plot(xs_mem, ys_mem, color=C_CEIL, lw=2.6)
    ax.plot(xs_cmp, ys_cmp, color=C_CEIL, lw=2.6)
    ax.plot([ridge], [peak_flops], "o", color=C_RIDGE, ms=9, zorder=5)

    # etiquetas de los techos
    ax.text(ai_min * 1.4, peak_bw * ai_min * 1.5,
            f"Ancho de banda\n{peak_bw:.0f} GB/s (pico M4 Pro)",
            color=C_CEIL, rotation=34, fontsize=10.5, va="bottom")
    ax.text(ai_max * 0.28, peak_flops * 1.12,
            f"Techo de computo — {peak_flops:.0f} GFLOP/s (pico medido)",
            color=C_CEIL, ha="right", fontsize=10.5)
    ax.annotate(f"punto de quiebre\nAI = {ridge:.1f} flop/byte",
                xy=(ridge, peak_flops), xytext=(ridge * 0.9, peak_flops * 0.28),
                fontsize=9.5, color=C_RIDGE, ha="center",
                arrowprops=dict(arrowstyle="->", color=C_RIDGE, lw=1.3))

    def scatter(ai, gf, color, label, marker="o", dy=1.25):
        if ai is None or gf is None:
            return
        ax.plot([ai], [gf], marker, color=color, ms=13, zorder=6,
                markeredgecolor="white", markeredgewidth=1.2)
        ax.annotate(label, xy=(ai, gf), xytext=(ai, gf * dy),
                    fontsize=10.5, ha="center", color=color, fontweight="bold")

    # --- puntos de los benchmarks estandar ---
    scatter(hpl_intensity(rows), hpl, C_COMPUTE, "HPL", dy=0.55)

    # HPCG: intensidad aritmetica baja tipica de SpMV disperso (~0.2 flop/byte,
    # Dongarra et al. 2016). Memory-bound -> cae sobre la recta.
    hpcg = best_metric(rows, "hpcg")
    scatter(0.2, hpcg, C_MEMORY, "HPCG", dy=1.5)

    # --- nuestros puntos medidos (el diferenciador) ---
    nb = app_points(rows, "nbody")
    st = app_points(rows, "stencil")
    if nb:
        t = max(nb)
        # AI de nbody sale enorme (muy compute-bound); la fijamos hacia el
        # borde derecho para que sea legible sin salirse del eje. La etiqueta
        # va DEBAJO del punto para no chocar con el rotulo COMPUTE-BOUND.
        nb_x = ai_max * 0.30
        ax.plot([nb_x], [nb[t]["gflops"]], "D", color=C_COMPUTE, ms=13,
                zorder=6, markeredgecolor="white", markeredgewidth=1.2)
        ax.annotate(f"N-body (nuestra)\n{nb[t]['gflops']:.0f} GFLOP/s @ {t}h",
                    xy=(nb_x, nb[t]["gflops"]),
                    xytext=(nb_x, nb[t]["gflops"] * 0.42),
                    fontsize=10, ha="center", color=C_COMPUTE, fontweight="bold")
    if st:
        t = max(st)
        sx, sy = st[t]["ai"], st[t]["gflops"]
        ax.plot([sx], [sy], "D", color=C_MEMORY, ms=13, zorder=6,
                markeredgecolor="white", markeredgewidth=1.2)
        # etiqueta abajo-izquierda del punto, lejos del punto de quiebre
        ax.annotate(f"Stencil (nuestra)\n{sy:.0f} GFLOP/s @ {t}h",
                    xy=(sx, sy), xytext=(sx * 0.42, sy * 1.9),
                    fontsize=10, ha="center", color=C_MEMORY, fontweight="bold",
                    arrowprops=dict(arrowstyle="-", color=C_MEMORY, lw=1, alpha=.5))

    ax.set_xlim(ai_min, ai_max)
    ax.set_ylim(1, peak_flops * 3)
    ax.set_xlabel("Intensidad aritmetica  (FLOP / byte)")
    ax.set_ylabel("Rendimiento  (GFLOP/s)")
    ax.set_title("Modelo Roofline — por que el pico no es el rendimiento real",
                 fontweight="bold", pad=14)

    # zonas
    ax.axvspan(ai_min, ridge, color=C_MEMORY, alpha=0.05)
    ax.axvspan(ridge, ai_max, color=C_COMPUTE, alpha=0.05)
    ax.text(ai_min * 1.3, peak_flops * 2.2, "MEMORY-BOUND", color=C_MEMORY,
            fontsize=9, fontweight="bold", alpha=0.7)
    ax.text(ai_max * 0.5, peak_flops * 2.2, "COMPUTE-BOUND", color=C_COMPUTE,
            fontsize=9, fontweight="bold", alpha=0.7, ha="center")

    fig.tight_layout()
    out = OUT / "roofline.png"
    fig.savefig(out)
    plt.close(fig)
    frac = 100.0 * stencil_bw / peak_bw if stencil_bw else None
    frac_txt = f", stencil sostiene {frac:.0f}% del pico" if frac else ""
    print(f"roofline: {out}  (BW techo={peak_bw:.0f} GB/s pico M4 Pro, "
          f"computo={peak_flops:.0f} GFLOP/s medido, quiebre AI={ridge:.2f}{frac_txt})")


# ---------------------------------------------------------------------------
# 2. Escalamiento nbody vs stencil
# ---------------------------------------------------------------------------

def plot_scaling(rows):
    nb = app_points(rows, "nbody")
    st = app_points(rows, "stencil")
    if not nb or not st:
        print("scaling: faltan apps propias en el CSV, se omite")
        return

    fig, ax = plt.subplots(figsize=(8.5, 5.6))
    for pts, color, label in [(nb, C_COMPUTE, "N-body (compute-bound)"),
                              (st, C_MEMORY, "Stencil calor 3D (memory-bound)")]:
        threads = sorted(pts)
        base = pts[threads[0]]["gflops"]
        speedup = [pts[t]["gflops"] / base for t in threads]
        ax.plot(threads, speedup, "o-", color=color, lw=2.4, ms=8, label=label)
        for t, s in zip(threads, speedup):
            ax.annotate(f"{s:.1f}x", (t, s), textcoords="offset points",
                        xytext=(0, 9), ha="center", fontsize=9, color=color)

    threads = sorted(nb)
    ax.plot(threads, threads, "--", color="#999", lw=1.6, label="Ideal (lineal)")

    ax.set_xlabel("Hilos OpenMP")
    ax.set_ylabel("Speedup (x)")
    ax.set_title("Compute-bound sigue escalando; memory-bound se estanca",
                 fontweight="bold", pad=12)
    ax.set_xticks(threads)
    ax.legend(frameon=False, loc="upper left")
    fig.tight_layout()
    out = OUT / "scaling_apps.png"
    fig.savefig(out)
    plt.close(fig)
    print(f"scaling: {out}")


# ---------------------------------------------------------------------------
# 3. HPL vs HPCG — la brecha
# ---------------------------------------------------------------------------

def plot_hpl_vs_hpcg(rows):
    hpl = hpl_peak_gflops(rows)
    hpcg = best_metric(rows, "hpcg")
    if not hpl or not hpcg:
        print("hpl_vs_hpcg: faltan datos, se omite")
        return
    frac = 100.0 * hpcg / hpl

    fig, ax = plt.subplots(figsize=(7.5, 5.6))
    bars = ax.bar(["HPL\n(computo denso,\nmaximo medido)",
                   "HPCG\n(carga representativa,\nmemory-bound)"],
                  [hpl, hpcg], color=[C_COMPUTE, C_MEMORY], width=0.6)
    for b, v in zip(bars, [hpl, hpcg]):
        ax.annotate(f"{v:.1f}", (b.get_x() + b.get_width() / 2, v),
                    textcoords="offset points", xytext=(0, 6),
                    ha="center", fontsize=13, fontweight="bold")
    ax.set_ylabel("GFLOP/s")
    ax.set_title(f"HPCG entrega {frac:.0f}% del rendimiento medido con HPL\n"
                 f"(una brecha de {hpl/hpcg:.0f}x en la misma maquina)",
                 fontweight="bold", fontsize=12.5, pad=12)
    ax.set_ylim(0, hpl * 1.2)
    fig.tight_layout()
    out = OUT / "hpl_vs_hpcg.png"
    fig.savefig(out)
    plt.close(fig)
    print(f"hpl_vs_hpcg: {out}  (HPCG = {frac:.1f}% de HPL)")


# ---------------------------------------------------------------------------
# 4. NPB: OpenMP vs MPI (overhead de comunicacion)
# ---------------------------------------------------------------------------

def plot_npb_omp_vs_mpi(rows, kernel="CG", cls="C"):
    omp, mpi = {}, {}
    for r in rows:
        if r["benchmark"] != "npb":
            continue
        notes = r["notes"]
        if note_get(notes, "kernel") != kernel or note_get(notes, "class") != cls:
            continue
        mode = note_get(notes, "mode")
        par = to_float(note_get(notes, "parallelism"))
        val = to_float(r["metric"])
        if par is None or val is None:
            continue
        (omp if mode == "omp" else mpi)[int(par)] = val
    if not omp or not mpi:
        print(f"npb_omp_vs_mpi: faltan datos para {kernel} clase {cls}, se omite")
        return

    fig, ax = plt.subplots(figsize=(8.5, 5.6))
    for data, color, label in [(omp, C_OMP, "OpenMP (memoria compartida)"),
                               (mpi, C_MPI, "MPI (memoria distribuida)")]:
        xs = sorted(data)
        ax.plot(xs, [data[x] / 1000.0 for x in xs], "o-", color=color, lw=2.4,
                ms=8, label=label)

    ax.set_xlabel("Grado de paralelismo (hilos OMP / procesos MPI)")
    ax.set_ylabel("Rendimiento (GOP/s)")
    ax.set_title(f"NPB {kernel} clase {cls}: mismo algoritmo, dos paradigmas",
                 fontweight="bold", pad=12)
    ax.set_xticks(sorted(set(omp) | set(mpi)))
    ax.legend(frameon=False, loc="upper left")
    fig.tight_layout()
    out = OUT / "npb_omp_vs_mpi.png"
    fig.savefig(out)
    plt.close(fig)
    print(f"npb_omp_vs_mpi: {out}  ({kernel} clase {cls})")


def main():
    if not CSV.exists():
        raise SystemExit(f"No existe {CSV} — corre antes python3 scripts/parse_results.py")
    OUT.mkdir(exist_ok=True)
    rows = load_rows()
    plot_roofline(rows)
    plot_scaling(rows)
    plot_hpl_vs_hpcg(rows)
    plot_npb_omp_vs_mpi(rows, kernel="CG", cls="C")
    print("\nListo. Graficas en analysis/*.png")


if __name__ == "__main__":
    main()
