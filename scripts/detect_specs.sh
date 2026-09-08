#!/usr/bin/env bash
# Detecta las specs reales de la maquina (o del contenedor) donde se corre.
# fuente unica de verdad para hpl/hpcg/stream: nada de numeros fijos aqui,
# todo se calcula desde /proc y /sys en el momento de correr.
#
# uso: se hace `source scripts/detect_specs.sh` y quedan disponibles
# variables tipo MEM_TOTAL_KB, CORES_LOGICAL, CORES_PHYSICAL, LLC_TOTAL_BYTES,
# CACHE_DETECTION_OK, CPU_MODEL, ARCH_UNAME, HOSTNAME_DETECTED.
#
# no usar `set -e` porque este script se hace source y no queremos matar
# la shell del que lo llama si algo falla; cada deteccion tiene su propio
# fallback.

# --- ram ---
MEM_TOTAL_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)"
MEM_AVAILABLE_KB="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null)"
if [[ -z "$MEM_TOTAL_KB" ]]; then
  echo "detect_specs: no se pudo leer /proc/meminfo, usando piso de 2GB" >&2
  MEM_TOTAL_KB=$((2 * 1024 * 1024))
fi
: "${MEM_AVAILABLE_KB:=$MEM_TOTAL_KB}"

# --- cores logicos ---
CORES_LOGICAL="$(nproc 2>/dev/null || echo 1)"

# --- cores fisicos ---
# contamos pares unicos (physical id, core id) de /proc/cpuinfo.
# en maquinas de un solo socket sin "physical id" (comun en arm64/vms)
# hacemos fallback a los logicos.
if [[ -r /proc/cpuinfo ]] && grep -q '^physical id' /proc/cpuinfo 2>/dev/null; then
  CORES_PHYSICAL="$(paste -d'-' \
      <(grep '^physical id' /proc/cpuinfo | awk '{print $NF}') \
      <(grep '^core id' /proc/cpuinfo | awk '{print $NF}') \
      | sort -u | wc -l)"
  if [[ -z "$CORES_PHYSICAL" || "$CORES_PHYSICAL" -eq 0 ]]; then
    CORES_PHYSICAL="$CORES_LOGICAL"
  fi
else
  CORES_PHYSICAL="$CORES_LOGICAL"
fi

# --- cache de ultimo nivel (llc) ---
# recorremos /sys/devices/system/cpu/cpu0/cache/index*/ para encontrar
# el nivel mas alto de cache, y sumamos su tamano deduplicando por
# shared_cpu_list (asi no contamos la misma cache fisica varias veces).
LLC_TOTAL_BYTES=0
LLC_LEVEL=0
CACHE_DETECTION_OK=1
CACHE_BASE="/sys/devices/system/cpu/cpu0/cache"

if [[ -d "$CACHE_BASE" ]]; then
  # primero encontramos el nivel mas alto disponible
  for idx in "$CACHE_BASE"/index*/; do
    [[ -f "${idx}level" ]] || continue
    lvl="$(cat "${idx}level" 2>/dev/null || echo 0)"
    if [[ "$lvl" =~ ^[0-9]+$ ]] && (( lvl > LLC_LEVEL )); then
      LLC_LEVEL="$lvl"
    fi
  done

  if (( LLC_LEVEL > 0 )); then
    declare -A seen_shared_lists=()
    for idx in "$CACHE_BASE"/index*/; do
      [[ -f "${idx}level" ]] || continue
      lvl="$(cat "${idx}level" 2>/dev/null || echo 0)"
      [[ "$lvl" == "$LLC_LEVEL" ]] || continue

      shared="$(cat "${idx}shared_cpu_list" 2>/dev/null || echo "unknown")"
      # ya contamos esta cache fisica (compartida por este set de cpus)
      [[ -n "${seen_shared_lists[$shared]:-}" ]] && continue
      seen_shared_lists["$shared"]=1

      size_raw="$(cat "${idx}size" 2>/dev/null || echo "")"
      # el formato tipico es "8192K" o "32M"
      if [[ "$size_raw" =~ ^([0-9]+)K$ ]]; then
        LLC_TOTAL_BYTES=$((LLC_TOTAL_BYTES + BASH_REMATCH[1] * 1024))
      elif [[ "$size_raw" =~ ^([0-9]+)M$ ]]; then
        LLC_TOTAL_BYTES=$((LLC_TOTAL_BYTES + BASH_REMATCH[1] * 1024 * 1024))
      elif [[ "$size_raw" =~ ^[0-9]+$ ]]; then
        LLC_TOTAL_BYTES=$((LLC_TOTAL_BYTES + size_raw))
      fi
    done
  fi
fi

# validamos que el numero tenga sentido. si algo huele raro, no abortamos:
# usamos un piso conservador y dejamos la bandera prendida para que
# el resto del pipeline (log + csv) sepa que esto no es confiable.
MIN_PLAUSIBLE_BYTES=$((4 * 1024 * 1024))          # 4 MiB
MAX_PLAUSIBLE_BYTES=$((512 * 1024 * 1024))        # 512 MiB (huele a hypervisor)
FALLBACK_LLC_BYTES=$((64 * 1024 * 1024))          # 64 MiB, sobredimensionar es lo seguro

if (( LLC_LEVEL < 3 )) || (( LLC_TOTAL_BYTES < MIN_PLAUSIBLE_BYTES )) || (( LLC_TOTAL_BYTES > MAX_PLAUSIBLE_BYTES )); then
  CACHE_DETECTION_OK=0
  LLC_TOTAL_BYTES=$FALLBACK_LLC_BYTES
fi

# --- info general ---
CPU_MODEL="$(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)"
: "${CPU_MODEL:=desconocido}"
ARCH_UNAME="$(uname -m 2>/dev/null || echo desconocido)"
HOSTNAME_DETECTED="$(hostname 2>/dev/null || echo desconocido)"

# export para que scripts hijos (build_*.sh, gen_*.py, run_*.sh) los reciban
export MEM_TOTAL_KB MEM_AVAILABLE_KB CORES_LOGICAL CORES_PHYSICAL
export LLC_TOTAL_BYTES LLC_LEVEL CACHE_DETECTION_OK
export CPU_MODEL ARCH_UNAME HOSTNAME_DETECTED

# resumen legible para debug manual (source no debe ser silencioso del todo)
if [[ "${DETECT_SPECS_QUIET:-0}" != "1" ]]; then
  cat >&2 <<EOF
[detect_specs] mem_total=${MEM_TOTAL_KB}KB mem_avail=${MEM_AVAILABLE_KB}KB
[detect_specs] cores_logicos=${CORES_LOGICAL} cores_fisicos=${CORES_PHYSICAL}
[detect_specs] llc_nivel=${LLC_LEVEL} llc_total=${LLC_TOTAL_BYTES}B cache_ok=${CACHE_DETECTION_OK}
[detect_specs] cpu="${CPU_MODEL}" arch=${ARCH_UNAME} host=${HOSTNAME_DETECTED}
EOF
fi
