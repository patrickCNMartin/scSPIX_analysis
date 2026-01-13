# Use a slim Python image
FROM python:3.12-slim

# Install uv directly from the official binary to keep the image light
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set the working directory
WORKDIR /app

# Enable bytecode compilation for faster startup
ENV UV_COMPILE_BYTECODE=1
# Prevent uv from looking for a project root in parent directories
ENV UV_PROJECT_ENVIRONMENT=/opt/venv

# 1. Install system dependencies (only what's strictly needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy dependency files first to leverage Docker layer caching
COPY pyproject.toml .
# If you have a lockfile, copy it too:
# COPY uv.lock . 

# 3. Install dependencies
# We use --no-install-project to install dependencies before copying the source code
RUN uv sync --no-install-project --no-dev

# 4. Install the GitHub package specifically
# You can also add this directly to your pyproject.toml instead
RUN uv pip install git+https://github.com/whistle-ch0i/SPIX

# 5. Copy the rest of your application code
COPY . .

# 6. Final sync to ensure the project itself is installed
RUN uv sync --no-dev

# Use the virtual environment by default
ENV PATH="/opt/venv/bin:$PATH"

# Set the entrypoint
ENTRYPOINT ["python"]
CMD ["-m", "your_main_script"]