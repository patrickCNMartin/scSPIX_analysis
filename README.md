# scSPIX Analysis

Reproducible analysis pipeline for the scSPIX package and paper. This project provides a Nextflow-based workflow for processing and analyzing spatial transcriptomics data, with containerized environments built using Nix for maximum reproducibility.

## Table of Contents

- [Project Structure](#project-structure)
- [Installation](#installation)
- [Building OCI Images from Nix](#building-oci-images-from-nix)
- [Development Environment](#development-environment)
- [Running the Pipeline](#running-the-pipeline)
- [Container Images](#container-images)
- [Contributing](#contributing)

## Project Structure

```
scSPIX_analysis/
├── bin/                          # Analysis scripts
│   ├── Stereo_seq_MOSTA_bin3_multiscale.py
│   ├── Stereopy_make_bin3_h5ad.py
│   ├── VisiumHD_2um_CRC_multiscale_workflow.py
│   └── VisiumHD_2um_make_zarr.py
├── container_cache/              # Cached container images (.tar, .sif)
│   ├── spix_analysis.tar
│   ├── stereopy.tar
│   └── visiumhd_zarr.tar
├── container_def/                # Container definitions
│   ├── spix/                     # SPIX analysis container
│   │   ├── Dockerfile
│   │   ├── spix_1007.yml        # Conda environment (for reference)
│   │   └── spix.def              # Singularity definition
│   ├── stereopy/                 # Stereopy container
│   │   ├── Dockerfile
│   │   ├── stereopy.yml
│   │   └── stereopy.def
│   └── visiumhd_zarr/            # VisiumHD Zarr container
│       ├── Dockerfile
│       ├── visiumhd_zarr.yml
│       └── visiumhd_zarr.def
├── data/                         # Input data directory
├── envs/                         # Environment YAML files (for reference)
├── lib/                          # Nextflow library functions
│   └── utils.nf
├── workflows/                    # Nextflow workflow definitions
│   ├── build_containers.nf
│   ├── container_converter.nf
│   ├── dwl_data.nf
│   ├── stereo_analysis_workflow.nf
│   ├── stereo_conversion.nf
│   └── visiumhd_analysis_workflow.nf
├── flake.nix                     # Nix flake configuration
├── flake.lock                    # Nix flake lock file
├── main.nf                       # Main Nextflow workflow
├── nextflow.config              # Nextflow configuration
└── README.md                     # This file
```

## Installation

### Prerequisites

- **Nix** (with Flakes enabled) - for building container images and development environment
- **Nextflow** - for running the analysis pipeline
- **Docker** or **Podman** - for running containerized workflows (optional, if using Nix-built images)

### Installing Nix

If you don't have Nix installed:

```bash
# Install Nix (single-user installation)
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# Enable Flakes (add to ~/.config/nix/nix.conf or /etc/nix/nix.conf)
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Setting Up the Development Environment

The project includes a Nix flake that provides a reproducible development environment:

```bash
# Enter the development shell
nix develop

# Or use direnv (recommended for automatic activation)
echo "use flake" > .envrc
direnv allow
```

The development shell includes:
- Python 3.12
- Nextflow
- Git
- PyYAML
- All necessary build tools

## Building OCI Images from Nix

This project uses Nix to build OCI (Open Container Initiative) images directly from nixpkgs, eliminating the need for Conda and ensuring reproducible builds.

### Available Images

The flake provides three container images:

- **spix-image**: Main SPIX analysis environment with all scientific Python packages
- **stereopy-image**: Stereopy-specific analysis environment
- **visiumhd-zarr-image**: VisiumHD Zarr processing environment

### Building Images

#### Option 1: Build to Default Location (Recommended)

Use the provided apps to build and copy images to `./container_cache`:

```bash
# Build and copy SPIX image
nix run .#copy-spix-image

# Build and copy Stereopy image
nix run .#copy-stereopy-image

# Build and copy VisiumHD Zarr image
nix run .#copy-visiumhd-zarr-image
```

Images will be saved as:
- `container_cache/spix-v0.0.1.tar`
- `container_cache/stereopy-v0.0.1.tar`
- `container_cache/visiumhd-zarr-v0.0.1.tar`

#### Option 2: Build to Custom Directory

```bash
# Copy to a custom directory
nix run .#copy-spix-image /path/to/your/directory
```

#### Option 3: Build Directly with Nix

```bash
# Build image (creates symlink at ./result)
nix build .#spix-image

# Load into Docker
docker load -i ./result

# Or load into Podman
podman load -i ./result
```

### Loading Images into Container Runtime

After building, load the images into your container runtime:

```bash
# Docker
docker load -i container_cache/spix-v0.0.1.tar
docker tag spix:v0.0.1 spix:latest  # Optional: add latest tag

# Podman
podman load -i container_cache/spix-v0.0.1.tar
podman tag spix:v0.0.1 spix:latest
```

### Image Contents

All images are built using:
- **Python 3.12** (matching the original Dockerfile base)
- **nixpkgs packages** instead of Conda for better reproducibility
- **Pip packages** for dependencies not available in nixpkgs (installed at build time)
- **System libraries** (zlib, openssl, libffi, etc.) from nixpkgs
- **Build tools** (gcc, make, etc.) for compiling Python packages

### Versioning

Images are tagged with semantic versions (currently `v0.0.1`). To update versions, modify the `tag` field in `flake.nix` for each image.

## Development Environment

### Using the Nix Development Shell

```bash
# Activate the development shell
nix develop

# The shell includes:
# - Python 3.12
# - Nextflow
# - Git
# - PyYAML
```

### Python Environments

You can also access the Python environments directly:

```bash
# Build Python environment (without container)
nix build .#spix-python

# Use the Python interpreter
./result/bin/python3
```

## Running the Pipeline

### Configuration

Edit `nextflow.config` to configure:
- Input data paths
- Output directories
- Which workflows to run (`run_stereo`, `run_visiumhd`)

### Running Workflows

```bash
# Run with default parameters
nextflow run main.nf

# Run with custom parameters
nextflow run main.nf \
  --run_stereo true \
  --run_visiumhd true \
  --outdir ./results
```

### Available Workflows

- **Stereo-seq**: Conversion and analysis of Stereo-seq data
- **VisiumHD**: Conversion and analysis of VisiumHD data
- **Container Conversion**: Automatic conversion of `.tar` to `.sif` files

## Container Images

### SPIX Image (`spix-image`)

Contains the complete SPIX analysis environment with:
- Scientific Python stack (numpy, scipy, pandas, matplotlib)
- Bioinformatics packages (scanpy, anndata, celltypist)
- Spatial analysis tools (squidpy, spatialdata, geopandas)
- Image processing (opencv, imageio, tifffile)
- Jupyter/IPython for interactive analysis

### Stereopy Image (`stereopy-image`)

Focused environment for Stereopy analysis:
- Stereopy package
- Scanpy and AnnData
- Core scientific Python packages

### VisiumHD Zarr Image (`visiumhd-zarr-image`)

Specialized for VisiumHD Zarr processing:
- Spatialdata-io for reading VisiumHD data
- Zarr support for efficient data storage
