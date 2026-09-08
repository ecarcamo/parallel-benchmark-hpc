#!/usr/bin/env bash
# Genera el bloque de trazabilidad que va al inicio de cada log de corrida.
# depende de que ya se haya hecho `source scripts/detect_specs.sh` antes.
#
# uso: source scripts/log_header.sh && print_log_header >> "$LOGFILE"
# variables opcionales de quien llama: MACHINE_ID, HOST_OS, y cualquier
# parametro extra de la corrida (ej. HPL_N, HPL_NB, HPCG_NX) pasado por env.

print_log_header() {
  local machine_id="${MACHINE_ID:-${HOSTNAME_DETECTED:-desconocido}}"
  local host_os="${HOST_OS:-desconocido}"

  echo "#META date=$(date -Is 2>/dev/null || date)"
  echo "#META machine_id=${machine_id}"
  echo "#META host_os=${host_os}"
  echo "#META hostname=${HOSTNAME_DETECTED:-desconocido}"
  echo "#META cpu_model=${CPU_MODEL:-desconocido}"
  echo "#META arch=${ARCH_UNAME:-desconocido}"
  echo "#META cores_logicos=${CORES_LOGICAL:-desconocido}"
  echo "#META cores_fisicos=${CORES_PHYSICAL:-desconocido}"
  echo "#META mem_total_kb=${MEM_TOTAL_KB:-desconocido}"
  echo "#META mem_available_kb=${MEM_AVAILABLE_KB:-desconocido}"
  echo "#META llc_total_bytes=${LLC_TOTAL_BYTES:-desconocido}"
  echo "#META llc_level=${LLC_LEVEL:-desconocido}"
  echo "#META cache_detection_ok=${CACHE_DETECTION_OK:-desconocido}"
  echo "#META uname=$(uname -a 2>/dev/null || echo desconocido)"
  echo "#META gcc_version=$(gcc --version 2>/dev/null | head -n1 || echo desconocido)"
  echo "#META mpirun_version=$(mpirun --version 2>/dev/null | head -n1 || echo desconocido)"
  echo "#META openblas_path=$(readlink -f /usr/lib/*/libopenblas.so 2>/dev/null || echo desconocido)"

  # parametros propios de la corrida que el que llama haya exportado antes.
  # no son obligatorios: cada wrapper (run_hpl.sh, run_hpcg.sh, run_sweep.sh)
  # exporta lo que le aplique.
  for var in RUN_PARAMS; do
    if [[ -n "${!var:-}" ]]; then
      echo "#META run_params=${!var}"
    fi
  done
}
