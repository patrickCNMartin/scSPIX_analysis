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


RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml .


RUN uv sync --no-install-project --no-dev



RUN uv sync --no-dev

ENV PATH="/opt/venv/bin:$PATH"

# Set the entrypoint
ENTRYPOINT ["python"]
CMD ["-m", "your_main_script"]