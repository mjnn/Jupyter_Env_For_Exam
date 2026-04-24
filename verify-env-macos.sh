#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
VENV_PY="$PROJECT_ROOT/.venv312/bin/python"
REQ_PATH="$PROJECT_ROOT/requirements-py312.txt"

if [[ ! -x "$VENV_PY" ]]; then
  echo "Virtual environment not found: $VENV_PY"
  exit 1
fi

if [[ ! -f "$REQ_PATH" ]]; then
  echo "Requirements file not found: $REQ_PATH"
  exit 1
fi

echo "==> Python version"
PY_VERSION="$("$VENV_PY" -c 'import platform; print(platform.python_version())')"
echo "Found Python: $PY_VERSION"
if [[ "$PY_VERSION" != "3.12.8" ]]; then
  echo "Python version mismatch. Expected 3.12.8, got $PY_VERSION"
  exit 1
fi

echo "==> Package version check"
"$VENV_PY" - "$REQ_PATH" <<'PYCODE'
import importlib.metadata as md
import json
import pathlib
import sys

req_path = pathlib.Path(sys.argv[1])
expected = {}
for line in req_path.read_text(encoding="utf-8").splitlines():
    s = line.strip()
    if not s or s.startswith("#"):
        continue
    if "==" not in s:
        continue
    name, version = s.split("==", 1)
    expected[name.lower()] = version

installed = {dist.metadata["Name"].lower(): dist.version for dist in md.distributions()}
mismatch = []
for name, version in expected.items():
    found = installed.get(name)
    if found is None:
        mismatch.append(f"Missing package: {name} (expected {version})")
    elif found != version:
        mismatch.append(f"Version mismatch: {name} expected {version} got {found}")

if mismatch:
    print("\n".join(mismatch))
    raise SystemExit(1)

print("All pinned packages match.")
PYCODE

echo "==> Jupyter kernel check"
if ! "$VENV_PY" -m jupyter kernelspec list --json | "$VENV_PY" - <<'PYCODE'
import json
import sys

data = json.load(sys.stdin)
if "py312-exam" not in data.get("kernelspecs", {}):
    raise SystemExit(1)
print("Kernel 'py312-exam' is registered.")
PYCODE
then
  echo "Kernel 'py312-exam' not found."
  exit 1
fi

echo
echo "Verification passed."
