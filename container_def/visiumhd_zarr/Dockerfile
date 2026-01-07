FROM python:3.12-slim

# Copy the conda environment file
COPY visiumhd_zarr.yml /tmp/visiumhd_zarr.yml

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
        curl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Install Miniconda
RUN set -eux && \
    wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    \
    # Apply TOS acceptance to the environment
    /opt/conda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    /opt/conda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    \
    # Configure conda
    /opt/conda/bin/conda config --system --prepend channels conda-forge && \
    /opt/conda/bin/conda update -n base conda -y && \
    \
    # Create the environment
    /opt/conda/bin/conda env create -f /tmp/visiumhd_zarr.yml && \
    \
    # Clean conda cache
    /opt/conda/bin/conda clean --all --yes


# Set the entrypoint to activate the spix environment
ENTRYPOINT ["conda", "run", "-n", "visiumhd_zarr", "--no-capture-output"]
CMD ["/bin/bash"]