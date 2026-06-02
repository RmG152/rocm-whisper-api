# 🚀 ROCm-Whisper-API

A Dockerized API server for OpenAI's Whisper, meticulously optimized for **AMD GPUs (ROCm)**. This project simplifies the deployment and utilization of the powerful Whisper model for speech-to-text transcription on AMD's accelerated hardware.

---

## ✨ Overview

This repository provides a streamlined solution to run the Whisper API leveraging the performance benefits of AMD's ROCm platform. It's designed for developers and enthusiasts looking to integrate high-performance audio transcription into their applications with AMD GPUs.

---

## 🔗 Project Links

* **GitHub Repository:** For the complete source code, detailed development insights, and the `Dockerfile`, please visit:
    👉 [**https://github.com/RmG152/rocm-whisper-api**](https://github.com/RmG152/rocm-whisper-api)

* **Docker Hub Image:** Pull the pre-built Docker image directly from Docker Hub:
    🐳 [**https://hub.docker.com/r/rmg152/rocm-whisper-api**](https://hub.docker.com/r/rmg152/rocm-whisper-api)

---

## 🛠️ Base PyTorch Container & Customization

This container is built upon a robust ROCm-enabled PyTorch image:
`rocm/pytorch:rocm7.2.2_ubuntu24.04_py3.12_pytorch_release_2.10.0`

**Want to use a different PyTorch version or a custom base image?**
No problem! The `Dockerfile` accepts a `BASE_TAG` build-arg, so you can pin any
modern `rocm/pytorch` image:
```bash
docker build --build-arg BASE_TAG=rocm6.4.4_ubuntu24.04_py3.12_pytorch_release_2.7.1 -t my-whisper .
```

### 🏷️ Available Image Tags

The CI workflow automatically builds and publishes **every modern**
`rocm/pytorch` upstream tag (ROCm 6.x & 7.x, Ubuntu 22.04/24.04, Python
3.10–3.13) on a weekly schedule.

Tag convention:
- **Full**: `rocmX.Y.Z-ubuntuYY.MM-pyA.B-pytorchC.D.E`  
  e.g. `rocm7.2.4-ubuntu24.04-py3.12-pytorch2.10.0`
- **Minor alias**: `rocmX.Y.Z` → always points to the latest py/pytorch combo  
  e.g. `rocm7.2.4`
- **Major alias**: `rocmX` → always points to the latest minor  
  e.g. `rocm7`
- **`latest`** → the upstream `rocm/pytorch:latest` (currently `rocm7.2.4-py3.12-pytorch2.10.0`)

Pull whatever you need:
```bash
docker pull rmg152/rocm-whisper-api:rocm7.2.4-ubuntu24.04-py3.12-pytorch2.10.0
docker pull rmg152/rocm-whisper-api:rocm7
docker pull rmg152/rocm-whisper-api:latest
```

See the [full list on Docker Hub →](https://hub.docker.com/r/rmg152/rocm-whisper-api/tags)

### 🤖 Automated updates

The `.github/workflows/build-matrix.yml` workflow:

1. Polls the [rocm/pytorch tags API](https://hub.docker.com/r/rocm/pytorch/tags) on
   **Mondays 06:00 UTC**.
2. Compares the upstream modern tags against what is already published in
   `rmg152/rocm-whisper-api` and only builds the **delta** (new tags).
3. Detects tags that have been removed from the upstream and **deletes them**
   from Docker Hub to keep the namespace tidy.
4. Re-tags the image built from the upstream `:latest` digest as
   `rmg152/rocm-whisper-api:latest`.

You can also trigger it manually from the **Actions** tab with filters
(`rocm_major`, `python`, `pytorch`) and a `dry_run` flag for safe inspection.

---

## ⚙️ Configuration & Environment Variables

Proper configuration through environment variables is essential for optimal performance. These variables are typically set within your `docker-compose.yml` file.

**Crucial Note on `HSA_OVERRIDE_GFX_VERSION`:**
It is vital to specify this variable if your AMD GPU model requires it for proper ROCm compatibility and performance. For example, users with an **AMD Radeon 780M** GPU **must** set this to `11.0.0` for correct operation.

**Whisper Model:**
Due to the constraints of the testing environment during development, the `base` Whisper model was used. You can adjust this to other models like `small`, `medium`, or `large` as per your requirements.

### Key Environment Variables:

* `HSA_OVERRIDE_GFX_VERSION`: Required for specific ROCm compatibility.
    * **Example:** `HSA_OVERRIDE_GFX_VERSION=11.0.0` (for AMD Radeon 780M)
* `WHISPER_MODEL`: Specifies the Whisper model to load.
    * **Example:** `WHISPER_MODEL=base`

---

## 📦 System Requirements

### Disk Space
**Minimum 95GB of free disk space is required for installation.**

This is primarily due to:
- Docker image size (ROCm-enabled PyTorch base image)
- Whisper model cache (depending on model size: base, small, medium, large)
- Container layers and temporary files during build/runtime

Ensure you have adequate storage available before proceeding with the installation.

## 🐳 Docker Compose Example

For simplified deployment and management of the ROCm-Whisper-API service, using a `docker-compose.yml` file is highly recommended. Below is a comprehensive example:

```yaml
services:
  rocm-whisper-api-service:
    image: RmG152/rocm-whisper-api:latest
    container_name: rocm-whisper-api
    restart: unless-stopped
    ports:
      - "8080:8080" # Maps container port 8080 on the host to container port 8080
    environment:
      - HSA_OVERRIDE_GFX_VERSION=11.0.0 # <<< IMPORTANT: Adjust this based on your specific AMD GPU model if needed
      - WHISPER_MODEL=base             # Change to 'small', 'medium', 'large', etc., as required
    devices:
      - "/dev/kfd:/dev/kfd" # Essential for ROCm Kernel Fusion Device access
      - "/dev/dri:/dev/dri" # Essential for Direct Rendering Infrastructure access for GPU
    volumes:
      - ~/.cache/whisper:/root/.cache/whisper
```

## 🙏 Acknowledgments

This project is based on the excellent work of the original author. Special thanks to **jjajjara** for creating the original [rocm-whisper-api](https://github.com/jjajjara/rocm-whisper-api) repository. Their innovative approach to optimizing Whisper for AMD GPUs using ROCm has made this technology accessible to the community.

## 🧪 How to Test

After successfully running the Docker container, you can test the API using the following methods:

### 1. cURL Test

You can send an audio file (e.g., `test.m4a`) to the API endpoint using `curl`:

```bash
curl -X POST -F "file=@test.m4a" http://localhost:8080/transcribe
```

### 2. Python Client Example

If your GitHub repository includes a `client_example.py` script, you can use it to test the API. Make sure `test.m4a` is in the same directory or provide the correct path.

```bash
python3 client_example.py test.m4a
```
