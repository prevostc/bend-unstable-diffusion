#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

if ! command -v bend >/dev/null 2>&1; then
  echo "Installing Bend from the official installer..."
  curl -fsSL https://bend-lang.com/install.sh | sh
fi

# Persist the conventional install location for future Codespaces shells.
if ! grep -Fq '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
fi

if ! command -v bend >/dev/null 2>&1; then
  echo "Bend was installed but is not on PATH." >&2
  echo "Inspect ~/.local/bin and the installer output." >&2
  exit 1
fi

echo "Bend ready:"
bend --version || true
printf '\nTry:\n  make run\n  make check\n  make proof\n'
