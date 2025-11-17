FROM python:3.12-slim

# Copy the conda environment file
COPY stereopy.yml /tmp/stereopy.yml

# Set environment variables
ENV PATH="/opt/conda/envs/stereopy/bin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    CONDA_DEFAULT_ENV=stereopy \
    CONDA_PREFIX=/opt/conda/envs/stereopy \
    PYTHONUNBUFFERED=1 \
    HOME=/home/appuser

# Install dependencies and set up environment
RUN set -eux && \
    # Update package manager
    apt-get update && \
    apt-get upgrade -y && \
    \
    # Install essential build tools
    apt-get install -y --no-install-recommends \
        build-essential \
        python3-dev \
        gcc \
        g++ \
        git \
        wget \
        curl \
        conda && \
    \
    # Clean up apt cache to reduce image size
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
    \
    # Initialize conda
    conda init bash && \
    \
    # Update conda base environment
    conda config --system --prepend channels conda-forge && \
    conda update -n base -c defaults conda -y && \
    \
    # Create and activate the spix environment from YAML
    conda env create -f /tmp/stereopy.yml && \
    \
    # Clean conda cache
    conda clean --all --yes && \
    \
    # Verify installation
    conda env list

# Set the entrypoint to activate conda and the spix environment
ENTRYPOINT ["bash", "-c", "source activate stereopy && exec \"$@\"", "--"]
CMD ["/bin/bash"]