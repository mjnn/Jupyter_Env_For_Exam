#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(basename "$SCRIPT_DIR")" == "offline-macos" ]]; then
  OFFLINE_ROOT="$SCRIPT_DIR"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  PROJECT_ROOT="$SCRIPT_DIR"
  OFFLINE_ROOT="$PROJECT_ROOT/offline-macos"
fi
WHEEL_DIR="$OFFLINE_ROOT/wheels"
PY_PKG="$OFFLINE_ROOT/python-3.12.8-macos11.pkg"
PY_BIN="/Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12"
VENV_PATH="$PROJECT_ROOT/.venv312"
REQ_PATH="$PROJECT_ROOT/requirements-py312.txt"
if [[ ! -f "$REQ_PATH" ]]; then
  REQ_PATH="$OFFLINE_ROOT/requirements-py312.txt"
fi

if [[ ! -f "$PY_PKG" ]]; then
  echo "Missing installer package: $PY_PKG"
  exit 1
fi
if [[ ! -d "$WHEEL_DIR" ]]; then
  echo "Missing wheel folder: $WHEEL_DIR"
  exit 1
fi
if [[ ! -f "$REQ_PATH" ]]; then
  echo "Missing requirements file. Expected in project root or offline-macos."
  exit 1
fi

export PIP_NO_INDEX=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
unset PIP_INDEX_URL PIP_EXTRA_INDEX_URL 2>/dev/null || true

echo "==> Installing Python 3.12.8 (requires sudo)..."
sudo installer -pkg "$PY_PKG" -target /

if [[ ! -x "$PY_BIN" ]]; then
  echo "Python install failed: $PY_BIN not found."
  exit 1
fi

echo "==> Creating virtual environment..."
"$PY_BIN" -m venv "$VENV_PATH"
VENV_PY="$VENV_PATH/bin/python"

echo "==> Installing dependencies from offline wheels (no network)..."
"$VENV_PY" -m pip install --isolated --no-index --find-links "$WHEEL_DIR" --upgrade pip setuptools
"$VENV_PY" -m pip install --isolated --no-index --find-links "$WHEEL_DIR" -r "$REQ_PATH"
"$VENV_PY" -m pip install --isolated --no-index --find-links "$WHEEL_DIR" ipykernel

echo "==> Registering Jupyter kernel..."
"$VENV_PY" -m ipykernel install --user --name py312-exam --display-name "Python 3.12 (exam-env)"

echo
echo "Offline install complete."
echo "Start Jupyter: ./launch-jupyter-macos.command"
