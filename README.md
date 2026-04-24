# Jupyter Exam Environment (Python 3.12.8)

This project sets up a Jupyter Notebook environment on machines that do not have Python preinstalled (Windows and macOS).

It uses `uv` to automatically install Python `3.12.8`, create a virtual environment, and install pinned package versions.

## Package Versions

See `requirements-py312.txt`.

Note: `pillow==9.5.0` is not recommended with Python 3.12.8 for cross-platform setup reliability. This environment uses `pillow==10.4.0`.

## Portable bundle (English-only; zero setup for students)

After extraction, students double-click **`START-Jupyter.bat`** (Windows) or **`START-Jupyter.command`** (macOS). All runtime files live under **`runtime/`**. Read **`README.txt`** in the bundle.

### Build on Windows (teacher machine, PowerShell)

1. (Recommended) `.\prepare-offline-windows.ps1`  
2. `Set-ExecutionPolicy -Scope Process Bypass; .\build-portable-windows.ps1`  

Outputs: `dist\JupyterExam-Portable-win64\`, `dist\JupyterExam-Portable-win64.zip`.

If Python 3.12 is already registered on the build PC, the installer may skip; the script then copies an existing **3.12.8** tree. Override with:

```powershell
$env:PREBUILT_PYTHON312 = 'D:\path\to\python312root'
.\build-portable-windows.ps1
```

The source folder must contain `python.exe` and be version **3.12.8**.

### Build on macOS (teacher machine; run on a real Mac)

1. (Recommended) `chmod +x prepare-offline-macos.sh && ./prepare-offline-macos.sh`  
2. `chmod +x build-portable-macos.sh && ./build-portable-macos.sh`  

Build **arm64** and **x86_64** bundles on matching Macs. Python is [python-build-standalone](https://github.com/astral-sh/python-build-standalone) **CPython 3.12.8 install_only** (tag `20241219`).

### Build macOS bundle without a local Mac (GitHub Actions)

Push this repo to GitHub, open **Actions → “Build portable macOS bundle” → Run workflow**.

- Default: builds on **`macos-latest`** (Apple Silicon) and uploads **`JupyterExam-Portable-mac-arm64.tar.gz`** as an artifact (installs deps from PyPI unless you enabled the optional prepare step).
- Optional checkbox **Run prepare-offline-macos.sh first**: slower, but matches an air-gapped wheel layout like your offline `offline-macos/wheels` workflow.
- **Intel (x86_64)** bundles are not produced on free GitHub runners today; build those on an Intel Mac or a paid macOS x86 runner.

Workflow file: `.github/workflows/build-portable-macos.yml`.

### Students (offline machines)

- **Windows**: Unzip, run **`START-Jupyter.bat`**. Notebooks default to **`runtime\notebooks`**. Optional: **`SELFTEST.bat`**.  
- **macOS**: Extract tarball, run **`START-Jupyter.command`**. If blocked: **System Settings → Privacy & Security → Open Anyway**. Optional: **`SELFTEST.command`**.

## Windows Setup

Open PowerShell in this folder and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\bootstrap-windows.ps1
```

Start Jupyter (isolated launch, recommended):

```powershell
.\launch-jupyter-windows.bat
```

Double-click launcher:

- `launch-jupyter-windows.bat`

## macOS Setup

Open Terminal in this folder and run:

```bash
chmod +x bootstrap-macos.sh
./bootstrap-macos.sh
```

Start Jupyter (isolated launch, recommended):

```bash
chmod +x launch-jupyter-macos.command
./launch-jupyter-macos.command
```

Double-click launcher:

- `chmod +x launch-jupyter-macos.command`
- Open `launch-jupyter-macos.command`

## Offline Setup (No Internet On Target Machine)

Important: prepare offline bundles on a machine with internet, and on the same OS/CPU architecture as the target machine.

### Zero-network target installs

On the **offline target machine**, `install-offline-*.` scripts are written so **pip never uses the network**:

- `PIP_NO_INDEX=1` (Windows: same env var) and every `pip install` uses `--no-index --find-links …/wheels`
- `pip install` also uses `--isolated` so user/global `pip.ini` index URLs are ignored
- The offline bundle includes wheels for **`pip` and `setuptools`** so upgrading pip on the target does not need PyPI

Re-run `prepare-offline-windows.ps1` / `prepare-offline-macos.sh` once after this change so those wheels are present in `wheels/`.

### Windows Offline

1) On an online Windows machine:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\prepare-offline-windows.ps1
```

2) Copy the whole project folder (including `offline-windows`) to the offline target machine.

3) On the offline target machine:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-offline-windows.ps1
```

You can run `install-offline-windows.ps1` either from project root or from inside `offline-windows`.

4) Start Jupyter:

```powershell
.\launch-jupyter-windows.bat
```

### macOS Offline

1) On an online macOS machine:

```bash
chmod +x prepare-offline-macos.sh
./prepare-offline-macos.sh
```

2) Copy the whole project folder (including `offline-macos`) to the offline target machine.

3) On the offline target machine:

```bash
chmod +x install-offline-macos.sh
./install-offline-macos.sh
```

You can run `install-offline-macos.sh` either from project root or from inside `offline-macos`.

4) Start Jupyter:

```bash
chmod +x launch-jupyter-macos.command
./launch-jupyter-macos.command
```

## Isolation Guarantee

This setup is isolated from any Python already installed on the machine:

- Jupyter always starts with project-local interpreter: `.venv312`
- launcher scripts verify interpreter version is exactly `3.12.8` before start
- startup uses Python flags `-E -s` to ignore external Python env vars and user site-packages
- launcher scripts clear `PYTHONHOME` and `PYTHONPATH` to prevent contamination from system config

Recommendation: always start with `launch-jupyter-windows.bat` or `launch-jupyter-macos.command` instead of plain `python -m notebook`.

## Optional: Use the Registered Kernel in Jupyter

Kernel name: `Python 3.12 (exam-env)`  
Kernel id: `py312-exam`

## Environment Verification

Use these scripts to verify:

- Python version is exactly `3.12.8`
- all pinned package versions match `requirements-py312.txt`
- Jupyter kernel `py312-exam` is registered

### Windows

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\verify-env-windows.ps1
```

### macOS

```bash
chmod +x verify-env-macos.sh
./verify-env-macos.sh
```
