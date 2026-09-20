#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

# Fast edit/check cycle: Bend's default JS lane.
bend main.bend
