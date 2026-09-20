FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Bend's JS/checker path doesn't need a C compiler, but having clang available
# lets the same Codespace compile native CPU binaries too.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      clang \
      build-essential \
      curl \
 && rm -rf /var/lib/apt/lists/*
