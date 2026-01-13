# scSPIX Analysis

Reproducible analysis pipeline for the scSPIX package and paper. This project provides a Nextflow-based workflow for processing and analyzing spatial transcriptomics data, with containerized environments built using Docker and managed with uv for Python dependencies.

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
3. **Build container images**: `docker build -t spix container_def/spix/`
4. **Run the pipeline**: `nextflow run main.nf`

That's it! Nix provides the development environment, Docker builds the containers.

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
├── container_def/                # Container definitions and Python environments
│   ├── spix/                     # SPIX analysis environment
│   │   ├── Dockerfile            # Docker image definition
│   │   ├── pyproject.toml        # Python dependencies (uv)
│   │   └── spix.def              # Singularity definition
│   ├── stereopy/                 # Stereopy environment
│   │   ├── Dockerfile
│   │   ├── pyproject.toml
│   │   └── stereopy.def
│   └── visiumhd_zarr/            # VisiumHD Zarr environment
│       ├── Dockerfile
│       ├── pyproject.toml
│       └── visiumhd_zarr.def
├── data/                         # Input data directory
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

Container images are built using Docker from the `container_def/` directory. Python dependencies are managed with uv for faster, more reliable builds.

### Available Images

- **spix**: Complete SPIX analysis environment (130+ Python packages)
- **stereopy**: Stereopy analysis tools
- **visiumhd-zarr**: VisiumHD Zarr data processing

### Building Images with Docker

```bash
# Build SPIX image
docker build -t spix container_def/spix/

# Build Stereopy image
docker build -t stereopy container_def/stereopy/

# Build VisiumHD Zarr image
docker build -t visiumhd-zarr container_def/visiumhd_zarr/
```

### What Happens During Build

Each Dockerfile:
1. Uses Python 3.12 base image
2. Installs uv package manager
3. Copies `pyproject.toml` with all dependencies
4. Runs `uv sync` to install Python packages
5. Sets up the container for Nextflow execution

### Saving Images (Optional)

Save built images for sharing or backup:

```bash
# Save images to container_cache/
docker save spix > container_cache/spix.tar
docker save stereopy > container_cache/stereopy.tar
docker save visiumhd-zarr > container_cache/visiumhd-zarr.tar
```

### Loading Saved Images

```bash
# Load from saved tar files
docker load -i container_cache/spix.tar
docker load -i container_cache/stereopy.tar
docker load -i container_cache/visiumhd-zarr.tar
```

## Development Environment

### What Nix Provides

Nix manages the **system-level dependencies** and development tools. Python packages are managed separately with uv.

When you run `nix develop`, you get:
- **Python 3.12** interpreter
- **uv** package manager (for Python dependencies)
- **Nextflow** for running analysis pipelines
- **Git** for version control
- **System libraries** needed for scientific computing

### Using the Development Environment

```bash
# Enter development environment
nix develop

# You're now ready to:
# - Run Nextflow pipelines
# - Use Python with all scientific packages
# - Build container images
# - Run analysis scripts from bin/
```

### Setting Up Python Environment with uv

Once in the Nix environment, set up Python dependencies:

```bash
# Navigate to the SPIX environment definition
cd container_def/spix

# Install Python dependencies with uv (fast!)
uv sync

# Activate the virtual environment
source .venv/bin/activate

# Test the environment
python -c "import scanpy, squidpy; print('SPIX environment ready!')"
```

**For automatic activation (optional):**

```bash
# Install direnv
# macOS: brew install direnv
# Linux: your package manager

# Set up automatic Nix environment activation
echo "use flake" > .envrc
direnv allow
```

### Python Environment Management

- **uv sync**: Install/update all Python dependencies from `pyproject.toml`
- **source .venv/bin/activate**: Activate the virtual environment
- **uv add package**: Add new dependencies to `pyproject.toml`
- **uv remove package**: Remove dependencies

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

All images are built from `pyproject.toml` files using Docker with uv for Python dependency management.

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
# Ensure Docker can write to current directory
# No special permissions needed for Docker builds
```

**Docker build fails**
```bash
# Check Docker is running
docker info

# Clean up failed builds
docker system prune
```

**uv sync fails in Docker**
```bash
# Check network connectivity in container
# uv may need internet access for package downloads
```

### Pipeline Issues

**"Nextflow not found"**
- Make sure you're in `nix develop` environment
- Check: `which nextflow`

**"Container not found"**
- Ensure images are built and loaded: `docker images`
- Check container_cache/ directory

## Contributing

To modify the Python environments:

1. Edit `container_def/*/pyproject.toml` files
2. Add/remove dependencies as needed
3. Test with: `nix develop` then `cd container_def/spix && uv sync`
4. Rebuild containers: `docker build -t spix container_def/spix/`

The `pyproject.toml` files define all Python dependencies managed by uv.
