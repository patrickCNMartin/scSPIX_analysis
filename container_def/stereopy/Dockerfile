# Using Python 3.8 on Bullseye (Debian 11) for compatibility
FROM python:3.8-slim-bullseye

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install system dependencies
# Added pkg-config and libxml2-dev which are often needed by bio-informatics stacks
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libstdc++6 \
    libsqlite3-dev \
    libicu-dev \
    libxml2-dev \
    pkg-config \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages directly
# We group them to allow pip to resolve dependencies (like numpy versions) together
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    ipython \
    anndata \
    scanpy \
    stereopy


# Default command
CMD ["ipython"]