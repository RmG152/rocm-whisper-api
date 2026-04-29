# Use official PyTorch image with ROCm support
# Tag can be adjusted according to available ROCm versions
# (https://hub.docker.com/r/rocm/pytorch/tags)
FROM rocm/pytorch:rocm7.2.2_ubuntu24.04_py3.12_pytorch_release_2.10.0

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
