FROM mambaorg/micromamba:2.3.2

WORKDIR /app
COPY --chown=$MAMBA_USER:$MAMBA_USER spix_1007.yml /tmp/spix_1007.yml
RUN micromamba install -y -n base -f /tmp/spix_1007.yml && \
    micromamba clean --all --yes


# Set environment variables
ENV HOME=/app \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/conda/bin:$PATH" \
    MAMBA_ROOT_PREFIX="/opt/conda"