#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
OFFLINE_ROOT="$PROJECT_ROOT/offline-macos"
WHEEL_DIR="$OFFLINE_ROOT/wheels"
BUILD_VENV="$OFFLINE_ROOT/.build-venv"
REQ_PATH="$PROJECT_ROOT/requirements-py38.txt"
PY_PKG="$OFFLINE_ROOT/python-3.8.10-macos11.pkg"
PY_URL="https://www.python.org/ftp/python/3.8.10/python-3.8.10-macos11.pkg"

mkdir -p "$WHEEL_DIR"

echo "==> Checking uv..."
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv install failed. Open a new terminal and run again."
  exit 1
fi

echo "==> Creating build venv (Python 3.8.10)..."
uv venv --python 3.8.10 "$BUILD_VENV"
BUILD_PY="$BUILD_VENV/bin/python"

echo "==> Ensuring pip in build venv..."
"$BUILD_PY" -m ensurepip --upgrade
"$BUILD_PY" -m pip install --upgrade pip

echo "==> Downloading wheels for offline install..."
"$BUILD_PY" -m pip download --only-binary=:all: -r "$REQ_PATH" -d "$WHEEL_DIR"
"$BUILD_PY" -m pip download --only-binary=:all: ipykernel -d "$WHEEL_DIR"

echo "==> Downloading pip / setuptools (for zero-network target upgrade)..."
"$BUILD_PY" -m pip download pip setuptools -d "$WHEEL_DIR"

echo "==> Downloading Python 3.8.10 installer package..."
curl -fL "$PY_URL" -o "$PY_PKG"

echo "==> Copying required files into offline bundle..."
cp -f "$REQ_PATH" "$OFFLINE_ROOT/requirements-py38.txt"
if [[ -f "$PROJECT_ROOT/install-offline-macos.sh" ]]; then
  cp -f "$PROJECT_ROOT/install-offline-macos.sh" "$OFFLINE_ROOT/install-offline-macos.sh"
fi

echo
echo "Offline bundle ready at: $OFFLINE_ROOT"
echo "Copy 'offline-macos' + project files to target macOS machine."
