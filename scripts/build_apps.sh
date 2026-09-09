#!/usr/bin/env bash
# Compila las dos aplicaciones propias (workloads de diseno propio):
#   - nbody   : compute-bound  (todos-contra-todos O(n^2))
#   - stencil : memory-bound   (difusion de calor 3D, Jacobi 7 puntos)
# Ambas son el diferenciador del proyecto: nos dan dos puntos MEDIDOS por
# nosotros que caen en extremos opuestos del modelo Roofline.
#
# uso: ./scripts/build_apps.sh
# salida: apps/nbody y apps/stencil
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPS_DIR="${ROOT_DIR}/apps"

# mismas flags que el resto del repo (ver scripts/env.sh). -march=native
# para que use el set de instrucciones real de la Mac de referencia.
# NADA de -ffast-math: cambiaria el conteo de flops y la validez numerica.
CC="${CC:-gcc}"
CFLAGS="-O3 -march=native -fopenmp"

echo "build_apps: compilando nbody..."
"$CC" $CFLAGS "${APPS_DIR}/nbody.c" -o "${APPS_DIR}/nbody" -lm

echo "build_apps: compilando stencil..."
"$CC" $CFLAGS "${APPS_DIR}/stencil.c" -o "${APPS_DIR}/stencil" -lm

echo "build_apps: listo -> ${APPS_DIR}/nbody  ${APPS_DIR}/stencil"
