# Use a slim bullseye image for better compatibility with older Python 3.8
FROM python:3.12-slim-bullseye

# Install uv directly from the official binary
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set working directory
WORKDIR /app

# Install system dependencies required for stereopy's C extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libstdc++6 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy your pyproject.toml
COPY pyproject.toml .

# 1. Create the environment and sync dependencies
# 2. uv will automatically download and use Python 3.8 as defined in pyproject.toml
# 3. We use --frozen to ensure the lockfile is respected (if you have one)
RUN uv venv --python 3.8 && \
    uv pip install .

# Ensure the virtualenv is on the PATH
ENV PATH="/app/.venv/bin:$PATH"

# Stereopy often needs to know where system libs are
ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"

# Default command
CMD ["python"]