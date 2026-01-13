# Use a slim Python image
FROM python:3.12-slim

# Install uv from the official binary
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set working directory
WORKDIR /app

# Enable bytecode compilation for performance and set the venv path
ENV UV_COMPILE_BYTECODE=1
ENV UV_PROJECT_ENVIRONMENT=/opt/venv

# 1. Install minimal system build tools
# visiumhd/zarr often requires build-essential for C-extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy the pyproject.toml
# If you are still using the .yml file, you should migrate those 
# dependencies into a pyproject.toml in this directory.
COPY pyproject.toml .
# COPY uv.lock . # Uncomment if you have a lockfile

# 3. Install dependencies
# This creates the virtual environment in /opt/venv
RUN uv sync --no-install-project --no-dev

# 4. Copy the rest of your application
COPY . .

# 5. Final sync to install the local project
RUN uv sync --no-dev

# Place the virtual environment's bin on the PATH
ENV PATH="/opt/venv/bin:$PATH"

# Entrypoint setup
# Unlike Conda, we don't need "uv run" if we've updated the PATH
ENTRYPOINT ["python"]
CMD ["--version"]