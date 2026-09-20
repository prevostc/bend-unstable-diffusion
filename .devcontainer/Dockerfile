FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

USER root

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      clang \
      curl \
      python3 \
      python3-pip \
 && rm -rf /var/lib/apt/lists/*

USER vscode

ENV PATH="/home/vscode/.bend/bin:${PATH}"

RUN curl -fsSL https://bend-lang.com/install.sh | sh \
 && bend version \
 && python3 --version

WORKDIR /workspaces