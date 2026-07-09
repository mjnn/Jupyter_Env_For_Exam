param(
    [ValidateSet("win10plus", "win7-legacy")]
    [string]$Profile = "win10plus"
)

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

$WheelDir = Join-Path $OfflineRoot "wheels-$Profile"
$PyInstaller = Join-Path $OfflineRoot "python-3.8.10-amd64.exe"
$PythonHome = Join-Path $ProjectRoot "python38"
$VenvPath = Join-Path $ProjectRoot ".venv38"
$ReqFileName = if ($Profile -eq "win7-legacy") { "requirements-py38-win7-legacy.txt" } else { "requirements-py38-win10plus.txt" }
$ReqPath = Join-Path $ProjectRoot $ReqFileName
if (-not (Test-Path $ReqPath)) {
    $ReqPath = Join-Path $OfflineRoot $ReqFileName
}

if (-not (Test-Path $PyInstaller)) {
    throw "Missing installer: $PyInstaller"
}
if (-not (Test-Path $WheelDir)) {
    throw "Missing wheels folder: $WheelDir"
}
if (-not (Test-Path $ReqPath)) {
    throw "Missing requirements file. Expected '$ReqFileName' in project root or offline-windows."
}

# Target machine: never contact PyPI or any index (ignore user/global pip.ini too).
$env:PIP_NO_INDEX = "1"
$env:PIP_DISABLE_PIP_VERSION_CHECK = "1"
Remove-Item Env:PIP_INDEX_URL -ErrorAction SilentlyContinue
Remove-Item Env:PIP_EXTRA_INDEX_URL -ErrorAction SilentlyContinue

Write-Host "==> Installing Python 3.8.10 locally..."
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
    (Join-Path $env:LocalAppData "Programs\Python\Python38\python.exe"),
    (Join-Path $env:LocalAppData "Programs\Python\Python38-32\python.exe")
)
foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
        $PythonExe = $candidate
        break
    }
}
if (-not $PythonExe -and (Get-Command py -ErrorAction SilentlyContinue)) {
    try {
        $pyPath = & py -3.8 -c "import sys; print(sys.executable)"
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
if ($LASTEXITCODE -ne 0) { throw "pip bootstrap failed (exit $LASTEXITCODE)" }
& $VenvPython @pipBase -r $ReqPath
if ($LASTEXITCODE -ne 0) { throw "pip install requirements failed (exit $LASTEXITCODE)" }

Write-Host "==> Registering Jupyter kernel..."
$kernelName = if ($Profile -eq "win7-legacy") { "py38-win7-exam" } else { "py38-win10plus-exam" }
$kernelDisplay = if ($Profile -eq "win7-legacy") { "Python 3.8 (win7-legacy exam-env)" } else { "Python 3.8 (win10plus exam-env)" }
& $VenvPython -m ipykernel install --user --name $kernelName --display-name $kernelDisplay

Write-Host ""
Write-Host "Offline install complete (profile: $Profile)."
Write-Host "Start Jupyter: .\launch-jupyter-windows.bat"
