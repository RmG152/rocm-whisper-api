# Use official PyTorch image with ROCm support.
# BASE_TAG is injected at build time (default = the tag this Dockerfile was
# originally written against). The CI matrix workflow in
# .github/workflows/build-matrix.yml overrides it for every supported
# rocm/pytorch upstream tag.
# Available tags: https://hub.docker.com/r/rocm/pytorch/tags
ARG BASE_TAG=rocm7.2.2_ubuntu24.04_py3.12_pytorch_release_2.10.0
FROM rocm/pytorch:${BASE_TAG}

# --- Install system dependencies ---
# Whisper requires ffmpeg for audio processing
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# --- Python application setup ---
# Set working directory
WORKDIR /app

# Copy requirements.txt first to leverage dependency caching
COPY app/requirements.txt .

# Upgrade pip and install libraries specified in requirements.txt
# torch is already included in the base image, so not installed here
RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY app/ .

# --- Container runtime configuration ---
# Expose port for API server
EXPOSE 8080

# Define command to run when container starts
# Run FastAPI application using Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
