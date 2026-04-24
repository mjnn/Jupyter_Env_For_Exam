#!/usr/bin/env bash
# macOS portable bundle: extract, double-click START-Jupyter.command. English-only README and messages.
# Python 3.8.10 is fetched with uv (managed interpreters) then copied into runtime/python.
# Recommended: ./prepare-offline-macos.sh first, then wheels install from offline-macos/wheels.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
REQ_FILE="$PROJECT_ROOT/requirements-py38.txt"
WHEEL_DIR="$PROJECT_ROOT/offline-macos/wheels"

if [[ ! -f "$REQ_FILE" ]]; then
  echo "Missing $REQ_FILE"
  exit 1
fi

ARCH_HW="$(uname -m)"
if [[ "$ARCH_HW" == "arm64" ]]; then
  BUNDLE_SUFFIX="arm64"
elif [[ "$ARCH_HW" == "x86_64" ]]; then
  BUNDLE_SUFFIX="x86_64"
else
  echo "Unsupported architecture: $ARCH_HW (need arm64 or x86_64)"
  exit 1
fi

BUNDLE_NAME="JupyterExam-Portable-py38-mac-${BUNDLE_SUFFIX}"
DIST_ROOT="$PROJECT_ROOT/dist/${BUNDLE_NAME}"
RUNTIME_DIR="$DIST_ROOT/runtime"
PY_ROOT="$RUNTIME_DIR/python"
NOTEBOOKS_DIR="$RUNTIME_DIR/notebooks"
TGZ_OUT="$PROJECT_ROOT/dist/${BUNDLE_NAME}.tar.gz"

echo "==> Checking uv..."
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required to fetch Python 3.8.10 for the portable bundle."
  exit 1
fi

echo "==> Cleaning..."
rm -rf "$DIST_ROOT" "$TGZ_OUT"
mkdir -p "$RUNTIME_DIR" "$NOTEBOOKS_DIR"

UV_PY_STORE="$PROJECT_ROOT/dist/_uv_python_dl"
rm -rf "$UV_PY_STORE"
mkdir -p "$UV_PY_STORE"
export UV_PYTHON_INSTALL_DIR="$UV_PY_STORE"

echo "==> Fetching managed Python 3.8.10 (uv)..."
uv python install 3.8.10
SRC_BIN="$(uv python find 3.8.10)"
if [[ -z "$SRC_BIN" || ! -x "$SRC_BIN" ]]; then
  echo "uv python find 3.8.10 failed"
  exit 1
fi
SRC_ROOT="$(cd "$(dirname "$SRC_BIN")/.." && pwd)"
mkdir -p "$PY_ROOT"
cp -a "$SRC_ROOT/." "$PY_ROOT/"
unset UV_PYTHON_INSTALL_DIR

PY_EXE=""
for cand in "$PY_ROOT/bin/python3.8" "$PY_ROOT/bin/python3"; do
  if [[ -x "$cand" ]]; then PY_EXE="$cand"; break; fi
done
if [[ -z "$PY_EXE" ]]; then
  echo "Bundled python missing under $PY_ROOT/bin"
  exit 1
fi

VER="$("$PY_EXE" -c 'import platform; print(platform.python_version())')"
if [[ "$VER" != "3.8.10" ]]; then
  echo "Unexpected Python version: $VER (expected 3.8.10)"
  exit 1
fi

echo "==> Installing dependencies..."
if [[ -d "$WHEEL_DIR" ]]; then
  export PIP_NO_INDEX=1
  unset PIP_INDEX_URL PIP_EXTRA_INDEX_URL 2>/dev/null || true
  echo "    (offline wheels: $WHEEL_DIR)"
  "$PY_EXE" -m pip install --isolated --no-index --find-links "$WHEEL_DIR" --upgrade pip setuptools
  "$PY_EXE" -m pip install --isolated --no-index --find-links "$WHEEL_DIR" -r "$REQ_FILE"
else
  unset PIP_NO_INDEX 2>/dev/null || true
  echo "    (PyPI - run ./prepare-offline-macos.sh first for offline-capable builds)"
  "$PY_EXE" -m pip install --isolated --upgrade pip setuptools
  "$PY_EXE" -m pip install --isolated -r "$REQ_FILE"
fi

echo "==> Writing launchers and README.txt..."
cat > "$DIST_ROOT/START-Jupyter.command" <<'CMD'
#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PY=""
for cand in "$ROOT/runtime/python/bin/python3.8" "$ROOT/runtime/python/bin/python3"; do
  if [[ -x "$cand" ]]; then PY="$cand"; break; fi
done
NB="$ROOT/runtime/notebooks"
export PYTHONHOME=""
export PYTHONPATH=""
export PYTHONNOUSERSITE=1

if [[ -z "$PY" ]]; then
  osascript -e 'display dialog "Bundled Python not found. Re-extract the full archive." buttons {"OK"} default button "OK"' || true
  exit 1
fi

VER="$("$PY" -c 'import platform; print(platform.python_version())')"
if [[ "$VER" != "3.8.10" ]]; then
  osascript -e "display dialog \"Wrong Python version: $VER (expected 3.8.10)\" buttons {\"OK\"} default button \"OK\"" || true
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
PY=""
for cand in "$ROOT/runtime/python/bin/python3.8" "$ROOT/runtime/python/bin/python3"; do
  if [[ -x "$cand" ]]; then PY="$cand"; break; fi
done
cd "$ROOT"
"$PY" -E -s -c "import platform; print('Python', platform.python_version()); import jupyter, numpy, pandas; print('OK: jupyter, numpy, pandas')"
osascript -e 'display dialog "Self-test finished. Check the terminal output." buttons {"OK"} default button "OK"' 2>/dev/null || true
CMD
chmod +x "$DIST_ROOT/SELFTEST.command"

cat > "$DIST_ROOT/README.txt" <<EOF
Jupyter Exam - macOS portable bundle (${BUNDLE_SUFFIX}, Python 3.8.10)

How to use
1. Extract ${BUNDLE_NAME}.tar.gz to get folder ${BUNDLE_NAME}.
2. Double-click START-Jupyter.command.
   If macOS blocks it: System Settings -> Privacy & Security -> Open Anyway.
3. Default notebooks folder: runtime/notebooks

Notes
- Python 3.8.10 and libraries are bundled; no Homebrew Python required.
- Use the arm64 tarball on Apple Silicon; use the x86_64 tarball on Intel Macs.
- If startup fails, run SELFTEST.command from Terminal and read errors.
- Do not delete or rename the runtime folder.

Teachers: chmod +x build-portable-macos.sh && ./build-portable-macos.sh
EOF

touch "$NOTEBOOKS_DIR/.gitkeep"

echo "==> Creating $TGZ_OUT ..."
mkdir -p "$PROJECT_ROOT/dist"
tar -czf "$TGZ_OUT" -C "$PROJECT_ROOT/dist" "$BUNDLE_NAME"

rm -rf "$UV_PY_STORE"

echo ""
echo "Done."
echo "  Folder: $DIST_ROOT"
echo "  TGZ:    $TGZ_OUT"
echo "Students: extract tarball, double-click START-Jupyter.command (see README.txt)"
