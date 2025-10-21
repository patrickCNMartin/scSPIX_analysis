FROM mambaorg/micromamba:2.3.2

WORKDIR /app
COPY --chown=$MAMBA_USER:$MAMBA_USER stereopy.yml /tmp/stereopy.yml
RUN micromamba install -y -n base -f /tmp/stereopy.yml && \
    micromamba clean --all --yes


# Set environment variables
ENV HOME=/app \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/conda/bin:$PATH" \
    MAMBA_ROOT_PREFIX="/opt/conda"