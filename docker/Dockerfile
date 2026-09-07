FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      gfortran \
      openmpi-bin \
      libopenmpi-dev \
      libopenblas-dev \
      cmake \
      make \
      git \
      wget \
      ca-certificates \
      python3 \
      python3-pip \
      python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Solo para las prácticas: el contenedor se ejecuta como root por defecto.
ENV OMPI_ALLOW_RUN_AS_ROOT=1 \
    OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

WORKDIR /work
CMD ["/bin/bash"]
