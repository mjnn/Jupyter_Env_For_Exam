# Windows portable bundle: extract, double-click START-Jupyter.bat. All ASCII paths under runtime\.
# Recommended: run prepare-offline-windows.ps1 first, then install from offline-windows\wheels.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Copy-PythonTree {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path (Join-Path $Source "python.exe"))) {
        return $false
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    robocopy $Source $Destination /MIR /COPY:DAT /R:2 /W:2 /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed with exit code $LASTEXITCODE (source: $Source)"
    }
    return $true
}

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BundleName = "JupyterExam-Portable-win64"
$DistRoot = Join-Path $ProjectRoot "dist\$BundleName"
$RuntimeDir = Join-Path $DistRoot "runtime"
$PythonDir = Join-Path $RuntimeDir "python"
$NotebooksDir = Join-Path $RuntimeDir "notebooks"
$ReqFile = Join-Path $ProjectRoot "requirements-py312.txt"
$WheelDir = Join-Path $ProjectRoot "offline-windows\wheels"
$OfflineInstaller = Join-Path $ProjectRoot "offline-windows\python-3.12.8-amd64.exe"
$TmpInstaller = Join-Path $ProjectRoot "dist\_tmp_python_installer.exe"
$InstallerUrl = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"
$ZipOut = Join-Path $ProjectRoot "dist\$BundleName.zip"

if (-not (Test-Path $ReqFile)) {
    throw "Missing requirements file: $ReqFile"
}

Write-Host "==> Cleaning previous bundle..."
if (Test-Path $DistRoot) { Remove-Item -Recurse -Force $DistRoot }
if (Test-Path $ZipOut) { Remove-Item -Force $ZipOut }
New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
New-Item -ItemType Directory -Force -Path $NotebooksDir | Out-Null

if (Test-Path $OfflineInstaller) {
    $Installer = $OfflineInstaller
    Write-Host "==> Using cached installer: $Installer"
}
else {
    Write-Host "==> Downloading Python 3.12.8 installer..."
    New-Item -ItemType Directory -Force -Path (Split-Path $TmpInstaller) | Out-Null
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $TmpInstaller
    $Installer = $TmpInstaller
}

Write-Host "==> Trying silent install of Python into bundle..."
New-Item -ItemType Directory -Force -Path $PythonDir | Out-Null
$installArgs = @(
    "/quiet",
    "InstallAllUsers=0",
    "Include_test=0",
    "Include_pip=1",
    "Include_launcher=0",
    "Include_exe=1",
    "Include_dev=0",
    "Include_lib=1",
    "Include_doc=0",
    "PrependPath=0",
    "TargetDir=$PythonDir"
)
$null = Start-Process -FilePath $Installer -ArgumentList $installArgs -Wait -PassThru

$PyExe = Join-Path $PythonDir "python.exe"
if (-not (Test-Path $PyExe)) {
    Write-Host "    Silent install did not populate TargetDir (common if Python 3.12 is already registered). Falling back to copying an existing 3.12.8 tree..."
    if (Test-Path $PythonDir) { Remove-Item -Recurse -Force $PythonDir }

    $candidates = @()
    if ($env:PREBUILT_PYTHON312) { $candidates += $env:PREBUILT_PYTHON312.TrimEnd('\') }
    $candidates += "D:\python3.12.8"
    $candidates += (Join-Path $env:LocalAppData "Programs\Python\Python312")
    $candidates += (Join-Path $ProjectRoot "python312")

    $copied = $false
    foreach ($src in $candidates) {
        if (-not $src) { continue }
        if (Test-Path $src) {
            Write-Host "    Trying copy from: $src"
            if (Copy-PythonTree -Source $src -Destination $PythonDir) {
                $ver = & (Join-Path $PythonDir "python.exe") -c "import platform; print(platform.python_version())"
                if ($ver -eq "3.12.8") {
                    $copied = $true
                    break
                }
                Write-Host "    Skipping (version $ver, need 3.12.8)"
                Remove-Item -Recurse -Force $PythonDir -ErrorAction SilentlyContinue
            }
        }
    }
    if (-not $copied) {
        throw @"
Could not place Python 3.12.8 into the bundle.
- On a clean PC, silent install should work.
- On a PC that already has Python 3.12, set PREBUILT_PYTHON312 to a folder that contains python.exe (3.12.8), e.g.:
  `$env:PREBUILT_PYTHON312='D:\python3.12.8'; .\build-portable-windows.ps1`
"@
    }
}

$PyExe = Join-Path $PythonDir "python.exe"
$pyVersion = & $PyExe -c "import platform; print(platform.python_version())"
if ($pyVersion -ne "3.12.8") {
    throw "Unexpected Python version in bundle: $pyVersion (expected 3.12.8)"
}

Write-Host "==> Installing pinned dependencies into portable python..."
if (Test-Path $WheelDir) {
    $env:PIP_NO_INDEX = "1"
    Remove-Item Env:PIP_INDEX_URL -ErrorAction SilentlyContinue
    Remove-Item Env:PIP_EXTRA_INDEX_URL -ErrorAction SilentlyContinue
    $pipBase = @("-m", "pip", "install", "--isolated", "--no-index", "--find-links", $WheelDir)
    Write-Host "    (offline wheels: $WheelDir)"
    & $PyExe @pipBase --upgrade pip setuptools
    & $PyExe @pipBase -r $ReqFile
}
else {
    Write-Host "    (PyPI - run prepare-offline-windows.ps1 first for reproducible offline builds)"
    Remove-Item Env:PIP_NO_INDEX -ErrorAction SilentlyContinue
    & $PyExe -m pip install --isolated --upgrade pip setuptools
    & $PyExe -m pip install --isolated -r $ReqFile
}

Write-Host "==> Writing launchers and README.txt (ASCII only)..."
$startBat = @"
@echo off
setlocal
cd /d "%~dp0"
set "PY=%~dp0runtime\python\python.exe"
set "PYTHONHOME="
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"

if not exist "%PY%" (
  echo ERROR: Bundled Python not found. Re-extract the full ZIP.
  pause
  exit /b 1
)

set "VFILE=%TEMP%\_jupyter_portable_ver_%RANDOM%%RANDOM%.tmp"
"%PY%" -E -s -c "import platform; print(platform.python_version())" 1>"%VFILE%" 2>nul
if not exist "%VFILE%" (
  echo ERROR: Could not run bundled Python to check version.
  pause
  exit /b 1
)
set "VER="
for /f "usebackq delims=" %%a in ("%VFILE%") do set "VER=%%a"
del "%VFILE%" >nul 2>&1
if not defined VER (
  echo ERROR: Empty Python version from bundled interpreter.
  pause
  exit /b 1
)
if not "%VER%"=="3.12.8" (
  echo ERROR: Wrong Python version: %VER% expected 3.12.8
  pause
  exit /b 1
)

echo Starting Jupyter Notebook...
echo Notebooks folder: %~dp0runtime\notebooks
start "" "%PY%" -E -s -m notebook --notebook-dir="%~dp0runtime\notebooks"
endlocal
"@
Set-Content -LiteralPath (Join-Path $DistRoot "START-Jupyter.bat") -Value $startBat -Encoding Ascii

$selfCheckBat = @"
@echo off
setlocal
cd /d "%~dp0"
set "PY=%~dp0runtime\python\python.exe"
"%PY%" -E -s -c "import platform; print('Python', platform.python_version()); import jupyter, numpy, pandas; print('OK: jupyter, numpy, pandas')"
pause
endlocal
"@
Set-Content -LiteralPath (Join-Path $DistRoot "SELFTEST.bat") -Value $selfCheckBat -Encoding Ascii

$readme = @"
Jupyter Exam - Windows portable bundle

How to use
1. Extract this folder anywhere (avoid non-ASCII paths if possible).
2. Double-click START-Jupyter.bat.
3. Put your .ipynb files in runtime\notebooks (default notebook dir).

Notes
- Python 3.12.8 and libraries are bundled; you do not need a system Python.
- If startup fails, run SELFTEST.bat and read the error.
- Do not delete or rename the runtime folder.

Teachers: rebuild with .\build-portable-windows.ps1
"@
Set-Content -LiteralPath (Join-Path $DistRoot "README.txt") -Value $readme -Encoding Ascii

"" | Set-Content -LiteralPath (Join-Path $NotebooksDir ".gitkeep") -Encoding ASCII

Write-Host "==> Creating ZIP (may take several minutes)..."
Compress-Archive -Path (Join-Path $DistRoot "*") -DestinationPath $ZipOut -Force

if (Test-Path $TmpInstaller) {
    Remove-Item -Force $TmpInstaller -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done."
Write-Host "  Folder: $DistRoot"
Write-Host "  ZIP:    $ZipOut"
Write-Host "Students: unzip, double-click START-Jupyter.bat (see README.txt)"
