#!/usr/bin/env bash
# Configuración común de compilación (dentro del contenedor Ubuntu).
export CC="gcc"
export OMPI_CC="gcc"
export CFLAGS="-O3 -march=native -fopenmp"
export LDFLAGS="-lopenblas"
export CPPFLAGS="-I/usr/include/openblas"
