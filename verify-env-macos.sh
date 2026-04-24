#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
VENV_PY="$PROJECT_ROOT/.venv38/bin/python"
REQ_PATH="$PROJECT_ROOT/requirements-py38.txt"

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
if [[ "$PY_VERSION" != "3.8.10" ]]; then
  echo "Python version mismatch. Expected 3.8.10, got $PY_VERSION"
  exit 1
fi

echo "==> Package version check"
"$VENV_PY" - "$REQ_PATH" <<'PYCODE'
import importlib.metadata as md
import pathlib
import sys
import platform

req_path = pathlib.Path(sys.argv[1])
expected = {}
for line in req_path.read_text(encoding="utf-8").splitlines():
    s = line.strip()
    if not s or s.startswith("#"):
        continue
    if ";" in s and "sys_platform" in s:
        main, marker = s.split(";", 1)
        if "win32" in marker and platform.system() != "Windows":
            continue
        s = main.strip()
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
KJSON=$("$VENV_PY" -m jupyter kernelspec list --json)
if ! echo "$KJSON" | "$VENV_PY" -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if "py38-exam" in d.get("kernelspecs",{}) else 1)'; then
  echo "Kernel 'py38-exam' not found."
  exit 1
fi
echo "Kernel 'py38-exam' is registered."

echo
echo "Verification passed."
