#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PY="$ROOT/.venv38/bin/python"
LOGDIR="$ROOT/logs"
export PYTHONHOME=""
export PYTHONPATH=""
export PYTHONNOUSERSITE=1

mkdir -p "$LOGDIR"
{
  echo "[$(date -Iseconds 2>/dev/null || date)] launch-jupyter-macos.command: begin"
} >>"$LOGDIR/launcher.log"

if [[ ! -x "$PY" ]]; then
  {
    echo "[$(date -Iseconds 2>/dev/null || date)] ERROR: venv not found"
  } >>"$LOGDIR/launcher.log"
  osascript -e 'display dialog "Environment not found. Run bootstrap-macos.sh first." buttons {"OK"} default button "OK"'
  exit 1
fi

VER="$("$PY" -c 'import platform; print(platform.python_version())')"
if [[ "$VER" != "3.8.10" ]]; then
  {
    echo "[$(date -Iseconds 2>/dev/null || date)] ERROR: version mismatch $VER"
  } >>"$LOGDIR/launcher.log"
  osascript -e "display dialog \"Python version mismatch in .venv38: $VER\" buttons {\"OK\"} default button \"OK\""
  exit 1
fi

{
  echo "[$(date -Iseconds 2>/dev/null || date)] starting notebook -> logs/jupyter.log"
} >>"$LOGDIR/launcher.log"

cd "$ROOT"
# Append server stdout/stderr; run in foreground until user stops Jupyter.
exec "$PY" -E -s -m notebook >>"$LOGDIR/jupyter.log" 2>&1
