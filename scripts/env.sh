#!/usr/bin/env bash
# Configuración común de compilación (dentro del contenedor Ubuntu).
export CC="gcc"
export OMPI_CC="gcc"
export CXX="g++"
export OMPI_CXX="g++"
export FC="gfortran"
export OMPI_FC="gfortran"
export CFLAGS="-O3 -march=native -fopenmp"
export CXXFLAGS="-O3 -march=native -fopenmp"
export LDFLAGS="-lopenblas"
# ojo: en ubuntu 24.04 los headers de openblas quedan en la carpeta
# multiarch (/usr/include/x86_64-linux-gnu), NO en /usr/include/openblas
# (esa ruta no existe, se verifico corriendo el contenedor real).
# gcc ya busca ahi por defecto, pero lo dejamos explicito por claridad.
export CPPFLAGS="-I/usr/include/$(gcc -dumpmachine 2>/dev/null || echo x86_64-linux-gnu)"
