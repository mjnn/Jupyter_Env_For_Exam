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

# Online prepare: must not use no-index / mirror-only config from the host (pip.ini, env vars).
$env:PIP_DISABLE_PIP_VERSION_CHECK = "1"
Remove-Item Env:PIP_NO_INDEX -ErrorAction SilentlyContinue
Remove-Item Env:PIP_INDEX_URL -ErrorAction SilentlyContinue
Remove-Item Env:PIP_EXTRA_INDEX_URL -ErrorAction SilentlyContinue
# Broken or stale proxy env vars cause pip to fail with ProxyError even when using PyPI directly.
foreach ($k in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")) {
    Remove-Item "Env:$k" -ErrorAction SilentlyContinue
}
# Bypass WinHTTP / IE auto-proxy for PyPI (broken PAC/proxy otherwise breaks pip on some Windows setups).
$env:NO_PROXY = "*"
$env:no_proxy = "*"

# pip global options must follow `pip` (not sit between `python -m` and `pip`).
function Invoke-PipDownload {
    param(
        [Parameter(Mandatory = $true)][string]$PythonExe,
        [Parameter(Mandatory = $true)][string[]]$ExtraArgs
    )
    $env:NO_PROXY = "*"
    $env:no_proxy = "*"
    $pipArgs = @(
        "-m", "pip", "download",
        "--isolated",
        "-i", "https://pypi.org/simple",
        "--trusted-host", "pypi.org",
        "--trusted-host", "files.pythonhosted.org"
    ) + $ExtraArgs
    & $PythonExe @pipArgs
    if ($LASTEXITCODE -ne 0) {
        throw "pip download failed (exit $LASTEXITCODE)."
    }
}

Write-Host "==> Creating build venv (Python 3.8.10)..."
uv venv --python 3.8.10 --clear $BuildVenv
$BuildPython = Join-Path $BuildVenv "Scripts\python.exe"

Write-Host "==> Bootstrapping modern pip (uv, avoids host pip.ini / old pip TLS issues)..."
uv pip install --python $BuildPython pip setuptools wheel

Write-Host "==> Downloading wheels for offline install..."
Invoke-PipDownload -PythonExe $BuildPython -ExtraArgs @(
    "--only-binary=:all:", "-r", $ReqPath, "-d", $WheelDir
)

Write-Host "==> Downloading pip / setuptools (for zero-network target upgrade)..."
Invoke-PipDownload -PythonExe $BuildPython -ExtraArgs @(
    "pip", "setuptools", "-d", $WheelDir
)

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
