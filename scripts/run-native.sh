#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

mkdir -p build
bend main.bend -o build/unstable-diffusion
THREADS="${1:-$(nproc)}"
./build/unstable-diffusion --threads "$THREADS"
