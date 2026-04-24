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
$PyInstaller = Join-Path $OfflineRoot "python-3.12.8-amd64.exe"
$PythonHome = Join-Path $ProjectRoot "python312"
$VenvPath = Join-Path $ProjectRoot ".venv312"
$ReqPath = Join-Path $ProjectRoot "requirements-py312.txt"
if (-not (Test-Path $ReqPath)) {
    $ReqPath = Join-Path $OfflineRoot "requirements-py312.txt"
}

if (-not (Test-Path $PyInstaller)) {
    throw "Missing installer: $PyInstaller"
}
if (-not (Test-Path $WheelDir)) {
    throw "Missing wheels folder: $WheelDir"
}
if (-not (Test-Path $ReqPath)) {
    throw "Missing requirements file. Expected in project root or offline-windows."
}

# Target machine: never contact PyPI or any index (ignore user/global pip.ini too).
$env:PIP_NO_INDEX = "1"
$env:PIP_DISABLE_PIP_VERSION_CHECK = "1"
Remove-Item Env:PIP_INDEX_URL -ErrorAction SilentlyContinue
Remove-Item Env:PIP_EXTRA_INDEX_URL -ErrorAction SilentlyContinue

Write-Host "==> Installing Python 3.12.8 locally..."
$installArgs = @(
    "/quiet",
    "InstallAllUsers=0",
    "Include_test=0",
    "Include_pip=1",
    "Include_launcher=1",
    "TargetDir=$PythonHome"
)
$proc = Start-Process -FilePath $PyInstaller -ArgumentList $installArgs -Wait -PassThru
$exitCode = $proc.ExitCode
if ($exitCode -ne 0 -and $exitCode -ne 3010) {
    throw "Python installer failed with exit code: $exitCode"
}

$PythonExe = $null
$candidates = @(
    (Join-Path $PythonHome "python.exe"),
    (Join-Path $env:LocalAppData "Programs\Python\Python312\python.exe"),
    (Join-Path $env:LocalAppData "Programs\Python\Python312-32\python.exe")
)
foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
        $PythonExe = $candidate
        break
    }
}
if (-not $PythonExe -and (Get-Command py -ErrorAction SilentlyContinue)) {
    try {
        $pyPath = & py -3.12 -c "import sys; print(sys.executable)"
        if ($pyPath -and (Test-Path $pyPath)) {
            $PythonExe = $pyPath
        }
    }
    catch {
        # ignore and continue to final validation
    }
}
if (-not $PythonExe) {
    throw "Python install completed but python.exe was not found."
}

Write-Host "==> Creating virtual environment..."
& $PythonExe -m venv $VenvPath
$VenvPython = Join-Path $VenvPath "Scripts\python.exe"

Write-Host "==> Installing dependencies from offline wheels (no network)..."
$pipBase = @("-m", "pip", "install", "--isolated", "--no-index", "--find-links", $WheelDir)
# pip/setuptools only: installing from .whl files does not require the "wheel" distribution on target.
& $VenvPython @pipBase --upgrade pip setuptools
& $VenvPython @pipBase -r $ReqPath
& $VenvPython @pipBase ipykernel

Write-Host "==> Registering Jupyter kernel..."
& $VenvPython -m ipykernel install --user --name py312-exam --display-name "Python 3.12 (exam-env)"

Write-Host ""
Write-Host "Offline install complete."
Write-Host "Start Jupyter: .\launch-jupyter-windows.bat"
