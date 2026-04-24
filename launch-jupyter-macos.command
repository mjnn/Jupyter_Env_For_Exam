#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PY="$ROOT/.venv312/bin/python"
export PYTHONHOME=""
export PYTHONPATH=""
export PYTHONNOUSERSITE=1

if [[ ! -x "$PY" ]]; then
  osascript -e 'display dialog "Environment not found. Run bootstrap-macos.sh first." buttons {"OK"} default button "OK"'
  exit 1
fi

VER="$("$PY" -c 'import platform; print(platform.python_version())')"
if [[ "$VER" != "3.12.8" ]]; then
  osascript -e "display dialog \"Python version mismatch in .venv312: $VER\" buttons {\"OK\"} default button \"OK\""
  exit 1
fi

cd "$ROOT"
"$PY" -E -s -m notebook
