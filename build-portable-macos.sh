#!/usr/bin/env bash
# macOS portable bundle: extract, double-click START-Jupyter.command. English-only README and messages.
# Uses astral-sh/python-build-standalone CPython 3.12.8 install_only (tag 20241219).
# Recommended: ./prepare-offline-macos.sh first, then wheels install from offline-macos/wheels.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
REQ_FILE="$PROJECT_ROOT/requirements-py312.txt"
WHEEL_DIR="$PROJECT_ROOT/offline-macos/wheels"

STANDALONE_TAG="20241219"
URL_AARCH64="https://github.com/astral-sh/python-build-standalone/releases/download/${STANDALONE_TAG}/cpython-3.12.8%2B${STANDALONE_TAG}-aarch64-apple-darwin-install_only.tar.gz"
URL_X86_64="https://github.com/astral-sh/python-build-standalone/releases/download/${STANDALONE_TAG}/cpython-3.12.8%2B${STANDALONE_TAG}-x86_64-apple-darwin-install_only.tar.gz"

if [[ ! -f "$REQ_FILE" ]]; then
  echo "Missing $REQ_FILE"
  exit 1
fi

ARCH_HW="$(uname -m)"
if [[ "$ARCH_HW" == "arm64" ]]; then
  STANDALONE_URL="$URL_AARCH64"
  BUNDLE_SUFFIX="arm64"
elif [[ "$ARCH_HW" == "x86_64" ]]; then
  STANDALONE_URL="$URL_X86_64"
  BUNDLE_SUFFIX="x86_64"
else
  echo "Unsupported architecture: $ARCH_HW (need arm64 or x86_64)"
  exit 1
fi

BUNDLE_NAME="JupyterExam-Portable-mac-${BUNDLE_SUFFIX}"
DIST_ROOT="$PROJECT_ROOT/dist/${BUNDLE_NAME}"
RUNTIME_DIR="$DIST_ROOT/runtime"
PY_ROOT="$RUNTIME_DIR/python"
NOTEBOOKS_DIR="$RUNTIME_DIR/notebooks"
TMP_TAR="$PROJECT_ROOT/dist/_tmp_python312_mac_${BUNDLE_SUFFIX}.tar.gz"
TGZ_OUT="$PROJECT_ROOT/dist/${BUNDLE_NAME}.tar.gz"

echo "==> Cleaning..."
rm -rf "$DIST_ROOT" "$TGZ_OUT"
mkdir -p "$RUNTIME_DIR" "$NOTEBOOKS_DIR"

echo "==> Downloading standalone Python 3.12.8 ($BUNDLE_SUFFIX)..."
curl -fL "$STANDALONE_URL" -o "$TMP_TAR"
tar -xzf "$TMP_TAR" -C "$RUNTIME_DIR"
rm -f "$TMP_TAR"

PY_BIN="$PY_ROOT/bin/python3.12"
if [[ ! -x "$PY_BIN" ]]; then
  echo "Expected python at $PY_BIN"
  exit 1
fi

VER="$("$PY_BIN" -c 'import platform; print(platform.python_version())')"
if [[ "$VER" != "3.12.8" ]]; then
  echo "Unexpected Python version: $VER (expected 3.12.8)"
  exit 1
fi

echo "==> Installing dependencies..."
if [[ -d "$WHEEL_DIR" ]]; then
  export PIP_NO_INDEX=1
  unset PIP_INDEX_URL PIP_EXTRA_INDEX_URL 2>/dev/null || true
  echo "    (offline wheels: $WHEEL_DIR)"
  "$PY_BIN" -m pip install --isolated --no-index --find-links "$WHEEL_DIR" --upgrade pip setuptools
  "$PY_BIN" -m pip install --isolated --no-index --find-links "$WHEEL_DIR" -r "$REQ_FILE"
else
  unset PIP_NO_INDEX 2>/dev/null || true
  echo "    (PyPI - run ./prepare-offline-macos.sh first for offline-capable builds)"
  "$PY_BIN" -m pip install --isolated --upgrade pip setuptools
  "$PY_BIN" -m pip install --isolated -r "$REQ_FILE"
fi

echo "==> Writing launchers and README.txt..."
cat > "$DIST_ROOT/START-Jupyter.command" <<'CMD'
#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PY="$ROOT/runtime/python/bin/python3.12"
NB="$ROOT/runtime/notebooks"
export PYTHONHOME=""
export PYTHONPATH=""
export PYTHONNOUSERSITE=1

if [[ ! -x "$PY" ]]; then
  osascript -e 'display dialog "Bundled Python not found. Re-extract the full archive." buttons {"OK"} default button "OK"' || true
  exit 1
fi

VER="$("$PY" -c 'import platform; print(platform.python_version())')"
if [[ "$VER" != "3.12.8" ]]; then
  osascript -e "display dialog \"Wrong Python version: $VER (expected 3.12.8)\" buttons {\"OK\"} default button \"OK\"" || true
  exit 1
fi

cd "$ROOT"
exec "$PY" -E -s -m notebook --notebook-dir="$NB"
CMD
chmod +x "$DIST_ROOT/START-Jupyter.command"

cat > "$DIST_ROOT/SELFTEST.command" <<'CMD'
#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PY="$ROOT/runtime/python/bin/python3.12"
cd "$ROOT"
"$PY" -E -s -c "import platform; print('Python', platform.python_version()); import jupyter, numpy, pandas; print('OK: jupyter, numpy, pandas')"
osascript -e 'display dialog "Self-test finished. Check the terminal output." buttons {"OK"} default button "OK"' 2>/dev/null || true
CMD
chmod +x "$DIST_ROOT/SELFTEST.command"

cat > "$DIST_ROOT/README.txt" <<EOF
Jupyter Exam - macOS portable bundle (${BUNDLE_SUFFIX})

How to use
1. Extract ${BUNDLE_NAME}.tar.gz to get folder ${BUNDLE_NAME}.
2. Double-click START-Jupyter.command.
   If macOS blocks it: System Settings -> Privacy & Security -> Open Anyway.
3. Default notebooks folder: runtime/notebooks

Notes
- Python 3.12.8 and libraries are bundled; no Homebrew Python required.
- Use the arm64 tarball on Apple Silicon; use the x86_64 tarball on Intel Macs.
- If startup fails, run SELFTEST.command from Terminal and read errors.
- Do not delete or rename the runtime folder.

Teachers: chmod +x build-portable-macos.sh && ./build-portable-macos.sh
EOF

touch "$NOTEBOOKS_DIR/.gitkeep"

echo "==> Creating $TGZ_OUT ..."
mkdir -p "$PROJECT_ROOT/dist"
tar -czf "$TGZ_OUT" -C "$PROJECT_ROOT/dist" "$BUNDLE_NAME"

echo ""
echo "Done."
echo "  Folder: $DIST_ROOT"
echo "  TGZ:    $TGZ_OUT"
echo "Students: extract tarball, double-click START-Jupyter.command (see README.txt)"
