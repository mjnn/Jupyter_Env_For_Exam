Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ((Split-Path $ScriptDir -Leaf) -eq "offline-windows") {
    $OfflineRoot = $ScriptDir
    $ProjectRoot = Split-Path -Parent $ScriptDir
}
else {
    $ProjectRoot = $ScriptDir
    $OfflineRoot = Join-Path $ProjectRoot "offline-windows"
}

$WheelDir = Join-Path $OfflineRoot "wheels"
$BuildVenv = Join-Path $OfflineRoot ".build-venv"
$ReqPath = Join-Path $ProjectRoot "requirements-py38.txt"
$PythonInstaller = Join-Path $OfflineRoot "python-3.8.10-amd64.exe"

if (-not (Test-Path $ReqPath)) {
    throw "Requirements file not found: $ReqPath"
}

New-Item -ItemType Directory -Force -Path $OfflineRoot | Out-Null
New-Item -ItemType Directory -Force -Path $WheelDir | Out-Null

Write-Host "==> Checking uv..."
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $UvBin = Join-Path $env:USERPROFILE ".local\bin"
    if (Test-Path $UvBin) {
        $env:PATH = "$UvBin;$env:PATH"
    }
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv install failed. Please restart PowerShell and run this script again."
}

Write-Host "==> Creating build venv (Python 3.8.10)..."
uv venv --python 3.8.10 $BuildVenv
$BuildPython = Join-Path $BuildVenv "Scripts\python.exe"

Write-Host "==> Ensuring pip is available in build venv..."
& $BuildPython -m ensurepip --upgrade
& $BuildPython -m pip install --upgrade pip

Write-Host "==> Downloading wheels for offline install..."
& $BuildPython -m pip download --only-binary=:all: -r $ReqPath -d $WheelDir
& $BuildPython -m pip download --only-binary=:all: ipykernel -d $WheelDir

Write-Host "==> Downloading pip / setuptools (for zero-network target upgrade)..."
& $BuildPython -m pip download pip setuptools -d $WheelDir

Write-Host "==> Downloading Python 3.8.10 installer..."
$PyUrl = "https://www.python.org/ftp/python/3.8.10/python-3.8.10-amd64.exe"
Invoke-WebRequest -Uri $PyUrl -OutFile $PythonInstaller

Write-Host "==> Copying required files into offline bundle..."
Copy-Item -Path $ReqPath -Destination (Join-Path $OfflineRoot "requirements-py38.txt") -Force
$InstallScript = Join-Path $ProjectRoot "install-offline-windows.ps1"
if (Test-Path $InstallScript) {
    Copy-Item -Path $InstallScript -Destination (Join-Path $OfflineRoot "install-offline-windows.ps1") -Force
}

Write-Host ""
Write-Host "Offline bundle ready at: $OfflineRoot"
Write-Host "Copy 'offline-windows' + project files to target Windows machine."
