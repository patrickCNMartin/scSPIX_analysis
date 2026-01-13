# Use a slim Python image
FROM python:3.12-slim

# Set environment variables to optimize Python behavior
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# 1. Install system dependencies
# build-essential is for C-extensions; git for potential github-hosted dependencies
# libgl1 and libglib2.0-0 are often needed for spatial/image libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 2. Upgrade pip and install the package directly
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir spatialdata-io

# 3. Copy your application scripts
COPY . .

# Entrypoint setup
ENTRYPOINT ["python"]
CMD ["--version"]