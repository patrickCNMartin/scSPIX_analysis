# scSPIX Analysis

Reproducible analysis pipeline for the scSPIX package and paper. This project provides a Nextflow-based workflow for processing and analyzing spatial transcriptomics data, with containerized environments built using Nix and uv for maximum reproducibility.

## Table of Contents

- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Development Environment](#development-environment)
- [Building Container Images](#building-container-images)
- [Running the Pipeline](#running-the-pipeline)
- [Container Images](#container-images)
- [Contributing](#contributing)

## Quick Start

If you're new to this project and want to re-run the analysis pipeline:

1. **Install Nix** (see [Installation](#installation) below)
2. **Set up development environment**: `nix develop`
3. **Build container images**: `nix run .#copy-spix-image`
4. **Run the pipeline**: `nextflow run main.nf`

That's it! The Nix flake handles all dependencies automatically.

## Project Structure

```
scSPIX_analysis/
├── bin/                          # Analysis scripts
│   ├── Stereo_seq_MOSTA_bin3_multiscale.py
│   ├── Stereopy_make_bin3_h5ad.py
│   ├── VisiumHD_2um_CRC_multiscale_workflow.py
│   └── VisiumHD_2um_make_zarr.py
├── container_cache/              # Cached container images (.tar files)
│   ├── spix-v0.0.1.tar
│   ├── stereopy-v0.0.1.tar
│   └── visiumhd-zarr-v0.0.1.tar
├── container_def/                # Legacy container definitions (for reference)
│   ├── spix/                     # SPIX analysis container
│   │   ├── Dockerfile
│   │   └── spix.def              # Singularity definition
│   ├── stereopy/                 # Stereopy container
│   │   ├── Dockerfile
│   │   └── stereopy.def
│   └── visiumhd_zarr/            # VisiumHD Zarr container
│       ├── Dockerfile
│       └── visiumhd_zarr.def
├── data/                         # Input data directory
├── uv-projects/                  # Python project definitions (uv/pyproject.toml)
│   ├── spix/                     # SPIX analysis environment
│   │   └── pyproject.toml
│   ├── stereopy/                 # Stereopy environment
│   │   └── pyproject.toml
│   └── visiumhd-zarr/            # VisiumHD Zarr environment
│       └── pyproject.toml
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

- **Nix** (with Flakes enabled) - handles all dependencies automatically
- **Nextflow** - included in the development environment
- **Docker** or **Podman** - for running containerized workflows

### Installing Nix

**What is Nix?** Nix is a package manager that creates reproducible development environments. It automatically handles Python versions, system libraries, and all dependencies.

**Installation steps:**

```bash
# Install Nix (single-user installation - recommended)
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# Enable Flakes (required for this project)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Restart your shell or run: source ~/.bashrc (or your shell's config)
```

**Verify installation:**
```bash
nix --version  # Should show version 2.18+
```

**Troubleshooting:**
- If you get permission errors, try: `sudo mkdir -p /nix && sudo chown $USER /nix`
- On macOS, you might need: `sudo launchctl kickstart -k system/org.nixos.nix-daemon`

### Setting Up the Development Environment

The development environment is managed by Nix and includes everything you need:

```bash
# Enter the development environment
cd /path/to/scSPIX_analysis
nix develop

# This automatically provides:
# - Python 3.12 with uv package manager
# - Nextflow for running pipelines
# - Git for version control
# - All system dependencies
```

**What happens when you run `nix develop`:**

1. Nix downloads and sets up Python 3.12
2. Installs uv (fast Python package manager)
3. Sets up the SPIX analysis environment automatically
4. Provides Nextflow and other tools

**For automatic environment activation (optional):**

```bash
# Install direnv (optional but recommended)
# On macOS: brew install direnv
# On Linux: your package manager

# Set up automatic activation
echo "use flake" > .envrc
direnv allow
```

Now every time you `cd` into the project directory, the environment activates automatically.

## Building Container Images

This project uses Nix to build container images directly from Python environments defined with uv. No Conda or Dockerfiles needed!

### Why Use Nix for Containers?

- **Reproducible**: Same image every time, regardless of system
- **Fast**: Incremental builds, only rebuilds what changed
- **No Docker daemon**: Builds directly to tar files
- **Small**: Only includes what's actually needed

### Available Images

- **spix-image**: Complete SPIX analysis environment (134+ Python packages)
- **stereopy-image**: Stereopy analysis tools
- **visiumhd-zarr-image**: VisiumHD Zarr data processing

### Quick Build (Recommended)

Build and save images to `container_cache/` automatically:

```bash
# Build all three images (run in development environment)
nix run .#copy-spix-image
nix run .#copy-stereopy-image
nix run .#copy-visiumhd-zarr-image
```

**What this does:**
- Downloads all dependencies
- Builds complete Python environments
- Creates OCI-compliant container images
- Saves as `.tar` files in `container_cache/`

### Loading Images

After building, load into Docker or Podman:

```bash
# Load SPIX image
docker load -i container_cache/spix-v0.0.1.tar

# Tag for convenience
docker tag spix:v0.0.1 spix:latest

# Verify
docker images | grep spix
```

### Advanced Usage

**Build to custom location:**
```bash
nix run .#copy-spix-image /my/custom/directory
```

**Build image directly (for inspection):**
```bash
nix build .#spix-image
ls -la result  # Shows the .tar file
```

**Access Python environments without containers:**
```bash
# Build Python environment only
nix build .#spix-python

# Use Python directly
./result/bin/python3 -c "import scanpy; print('Ready!')"
```

## Development Environment

### What the Development Environment Provides

When you run `nix develop`, you get:

- **Python 3.12** with uv package manager
- **Nextflow** for running analysis pipelines
- **Git** for version control
- **Complete SPIX environment** with all dependencies

### Using the Environment

```bash
# Enter development environment
nix develop

# You're now ready to:
# - Run Nextflow pipelines
# - Use Python with all scientific packages
# - Build container images
# - Run analysis scripts from bin/
```

### Python Package Management

The environment uses **uv** for fast, reliable Python package management:

```bash
# In development environment
cd uv-projects/spix
uv sync  # Install/update dependencies
source .venv/bin/activate  # Use the environment
python -c "import scanpy; print('SPIX ready!')"
```

### Direct Python Environment Access

Build Python environments without containers:

```bash
# Build SPIX Python environment
nix build .#spix-python

# Use Python directly
./result/bin/python3 script.py
```

## Running the Pipeline

### Prerequisites

1. **Enter development environment**: `nix develop`
2. **Build container images**: Follow [Building Container Images](#building-container-images)
3. **Prepare data**: Place input data in `data/` directory

### Configuration

Edit `nextflow.config` to set:
- `run_stereo = true` - Enable Stereo-seq analysis
- `run_visiumhd = true` - Enable VisiumHD analysis
- `outdir = "./results"` - Output directory
- Data input paths

### Running the Analysis

```bash
# In development environment
nextflow run main.nf

# With custom parameters
nextflow run main.nf \
  --run_stereo true \
  --run_visiumhd true \
  --outdir ./my_results
```

### What the Pipeline Does

- **Stereo-seq workflow**: Converts and analyzes Stereo-seq spatial data
- **VisiumHD workflow**: Processes VisiumHD data and creates Zarr files
- **Container conversion**: Converts `.tar` images to `.sif` (Singularity) format
- **Data download**: Downloads required datasets automatically

### Output

Results are saved to the configured output directory with organized subdirectories for each analysis type.

## Container Images

All images are built from `pyproject.toml` files using uv + Nix for reproducible environments.

### SPIX Image (`spix-image`)

Complete analysis environment with 130+ Python packages:
- **Core science**: numpy, scipy, pandas, matplotlib, scikit-learn
- **Bioinformatics**: scanpy, anndata, celltypist, squidpy
- **Spatial analysis**: spatialdata, geopandas, shapely
- **Image processing**: opencv, imageio, tifffile, scikit-image
- **Data formats**: zarr, h5py, xarray, dask
- **SPIX package**: From GitHub repository

### Stereopy Image (`stereopy-image`)

Streamlined for Stereopy workflows:
- Stereopy analysis package
- Scanpy and AnnData for single-cell analysis
- Essential scientific computing packages

### VisiumHD Zarr Image (`visiumhd-zarr-image`)

Optimized for VisiumHD data processing:
- spatialdata-io for reading VisiumHD datasets
- Zarr format support for efficient storage
- Core spatial analysis tools

## Troubleshooting

### Nix Installation Issues

**"command not found: nix"**
```bash
# Check if Nix is installed
which nix

# If not installed, reinstall
sh <(curl -L https://nixos.org/nix/install) --no-daemon
```

**"experimental features not enabled"**
```bash
# Enable flakes
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Development Environment Issues

**"cannot connect to socket"**
```bash
# Restart Nix daemon
sudo launchctl kickstart -k system/org.nixos.nix-daemon  # macOS
sudo systemctl restart nix-daemon  # Linux
```

**Slow first run**
- Nix downloads all dependencies on first use
- Subsequent runs are much faster
- Use `nix develop --offline` for offline work

### Container Building Issues

**"permission denied"**
```bash
# Ensure you can write to container_cache/
mkdir -p container_cache
```

**Out of disk space**
- Container builds need temporary space
- Clean up with: `nix-collect-garbage`

### Pipeline Issues

**"Nextflow not found"**
- Make sure you're in `nix develop` environment
- Check: `which nextflow`

**"Container not found"**
- Ensure images are built and loaded: `docker images`
- Check container_cache/ directory

## Contributing

To modify the Python environments:

1. Edit `uv-projects/*/pyproject.toml` files
2. Add/remove dependencies as needed
3. Test with: `nix develop` and `uv sync`
4. Rebuild containers: `nix run .#copy-*-image`

The Nix flake automatically picks up changes to `pyproject.toml` files.
