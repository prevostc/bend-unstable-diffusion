#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

if ! command -v nvcc >/dev/null 2>&1; then
  echo "CUDA is not available. GitHub Codespaces does not provide an NVIDIA GPU." >&2
  echo "Run this repo on a CUDA 12 Linux host for the GPU path." >&2
  exit 2
fi

mkdir -p build
bend gpu.bend -o build/unstable-diffusion-gpu
./build/unstable-diffusion-gpu --gpu "${GPU_HEAP:-4GB}"
