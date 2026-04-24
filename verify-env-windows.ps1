Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvPython = Join-Path $ProjectRoot ".venv312\Scripts\python.exe"
$ReqPath = Join-Path $ProjectRoot "requirements-py312.txt"

if (-not (Test-Path $VenvPython)) {
    throw "Virtual environment not found: $VenvPython"
}
if (-not (Test-Path $ReqPath)) {
    throw "Requirements file not found: $ReqPath"
}

$expected = @{}
Get-Content $ReqPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "==", 2
        if ($parts.Count -eq 2) {
            $expected[$parts[0].ToLower()] = $parts[1]
        }
    }
}

Write-Host "==> Python version"
$pyVersion = & $VenvPython -c "import platform; print(platform.python_version())"
Write-Host "Found Python: $pyVersion"
if ($pyVersion -ne "3.12.8") {
    throw "Python version mismatch. Expected 3.12.8, got $pyVersion"
}

Write-Host "==> Package version check"
$json = & $VenvPython -c "import json, importlib.metadata as md; print(json.dumps({d.metadata['Name'].lower(): d.version for d in md.distributions()}))"
$installedObj = $json | ConvertFrom-Json
$installed = @{}
foreach ($prop in $installedObj.PSObject.Properties) {
    $installed[$prop.Name] = [string]$prop.Value
}

$mismatch = @()
foreach ($k in $expected.Keys) {
    if (-not $installed.ContainsKey($k)) {
        $mismatch += "Missing package: $k (expected $($expected[$k]))"
    }
    elseif ($installed[$k] -ne $expected[$k]) {
        $mismatch += "Version mismatch: $k expected $($expected[$k]) got $($installed[$k])"
    }
}

if ($mismatch.Count -gt 0) {
    $mismatch | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw "Package verification failed."
}
Write-Host "All pinned packages match."

Write-Host "==> Jupyter kernel check"
$kernels = & $VenvPython -m jupyter kernelspec list --json | ConvertFrom-Json
$kernelNames = @($kernels.kernelspecs.PSObject.Properties.Name)
if ($kernelNames -notcontains "py312-exam") {
    throw "Kernel 'py312-exam' not found."
}
Write-Host "Kernel 'py312-exam' is registered."

Write-Host ""
Write-Host "Verification passed." -ForegroundColor Green
