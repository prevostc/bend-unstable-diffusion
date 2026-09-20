#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.bend/bin:$PATH"

if ! command -v bend >/dev/null 2>&1; then
  echo "Bend not found; installing..."
  curl -fsSL https://bend-lang.com/install.sh | sh
  export PATH="$HOME/.bend/bin:$PATH"
fi

if ! grep -Fq '.bend/bin' "$HOME/.bashrc" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.bend/bin:$PATH"\n' >> "$HOME/.bashrc"
fi

echo "Bend:"
bend version

echo "Python:"
python3 --version