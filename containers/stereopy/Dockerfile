FROM docker.io/mambaorg/micromamba:2.3.2@sha256:3f92db74f6780f60c9a2c6d983c76360a1d4cfdcb597395ab9e64747f067b15b

WORKDIR /app

USER root

RUN apt-get update && apt-get install -y \
    build-essential \
    python3-dev \
    gcc \
    g++ \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

USER mambauser

COPY --chown=$MAMBA_USER:$MAMBA_USER stereopy.yml /tmp/stereopy.yml
RUN micromamba install -y -n base -f /tmp/stereopy.yml && \
    micromamba clean --all --yes

# Set environment variables
ENV HOME=/app \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/conda/bin:$PATH" \
    MAMBA_ROOT_PREFIX="/opt/conda"