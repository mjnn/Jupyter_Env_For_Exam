Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvPath = Join-Path $ProjectRoot ".venv312"
$ReqPath = Join-Path $ProjectRoot "requirements-py312.txt"

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

Write-Host "==> Creating virtual environment with Python 3.12.8..."
uv venv --python 3.12.8 $VenvPath
$VenvPython = Join-Path $VenvPath "Scripts\python.exe"

Write-Host "==> Verifying Python version in venv..."
$pyVersion = & $VenvPython -c "import platform; print(platform.python_version())"
if ($pyVersion -ne "3.12.8") {
    throw "Unexpected Python version in venv: $pyVersion (expected 3.12.8)"
}

Write-Host "==> Installing dependencies..."
uv pip install --python "$VenvPython" -r $ReqPath

Write-Host "==> Registering Jupyter kernel..."
uv pip install --python "$VenvPython" ipykernel
& "$VenvPython" -m ipykernel install --user --name py312-exam --display-name "Python 3.12 (exam-env)"

Write-Host ""
Write-Host "Environment ready."
Write-Host "Activate with: .\.venv312\Scripts\Activate.ps1"
Write-Host "Start Jupyter with: .\launch-jupyter-windows.bat"
