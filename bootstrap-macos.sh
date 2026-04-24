#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
VENV_PATH="$PROJECT_ROOT/.venv38"
REQ_PATH="$PROJECT_ROOT/requirements-py38.txt"

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

echo "==> Creating virtual environment with Python 3.8.10..."
uv venv --python 3.8.10 "$VENV_PATH"
VENV_PY="$VENV_PATH/bin/python"

echo "==> Verifying Python version in venv..."
PY_VERSION="$("$VENV_PY" -c 'import platform; print(platform.python_version())')"
if [[ "$PY_VERSION" != "3.8.10" ]]; then
  echo "Unexpected Python version in venv: $PY_VERSION (expected 3.8.10)"
  exit 1
fi

echo "==> Installing dependencies..."
uv pip install --python "$VENV_PY" -r "$REQ_PATH"

echo "==> Registering Jupyter kernel..."
uv pip install --python "$VENV_PY" ipykernel
"$VENV_PY" -m ipykernel install --user --name py38-exam --display-name "Python 3.8 (exam-env)"

cat <<'EOF'

Environment ready.
Activate with: source .venv38/bin/activate
Start Jupyter with: ./launch-jupyter-macos.command
EOF
