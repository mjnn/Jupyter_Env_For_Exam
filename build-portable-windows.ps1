# Windows portable bundle: extract, double-click START-Jupyter.bat. All ASCII paths under runtime\.
# Recommended: run prepare-offline-windows.ps1 first, then install from offline-windows\wheels.
param(
    [ValidateSet("win10plus", "win7-legacy")]
    [string]$Profile = "win10plus"
)

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

function Find-SevenZip {
    foreach ($candidate in @(
            (Join-Path ${env:ProgramFiles} "7-Zip\7z.exe"),
            (Join-Path ${env:ProgramFiles(x86)} "7-Zip\7z.exe"),
            (Join-Path $env:LOCALAPPDATA "Programs\7-Zip\7z.exe")
        )) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    $cmd = Get-Command 7z -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }
    return $null
}

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BundleName = if ($Profile -eq "win7-legacy") { "JupyterExam-Portable-py38-win7-legacy" } else { "JupyterExam-Portable-py38-win10plus" }
$DistRoot = Join-Path $ProjectRoot "dist\$BundleName"
$RuntimeDir = Join-Path $DistRoot "runtime"
$PythonDir = Join-Path $RuntimeDir "python"
$NotebooksDir = Join-Path $RuntimeDir "notebooks"
$ReqFileName = if ($Profile -eq "win7-legacy") { "requirements-py38-win7-legacy.txt" } else { "requirements-py38-win10plus.txt" }
$ReqFile = Join-Path $ProjectRoot $ReqFileName
$WheelDir = Join-Path $ProjectRoot "offline-windows\wheels-$Profile"
$OfflineInstaller = Join-Path $ProjectRoot "offline-windows\python-3.8.10-amd64.exe"
$TmpInstaller = Join-Path $ProjectRoot "dist\_tmp_python_installer.exe"
$InstallerUrl = "https://www.python.org/ftp/python/3.8.10/python-3.8.10-amd64.exe"
$ZipOut = Join-Path $ProjectRoot "dist\$BundleName.zip"
$SevenZipOut = Join-Path $ProjectRoot "dist\$BundleName.7z"

if (-not (Test-Path $ReqFile)) {
    throw "Missing requirements file: $ReqFile"
}

Write-Host "==> Cleaning previous bundle..."
if (Test-Path $DistRoot) { Remove-Item -Recurse -Force $DistRoot }
if (Test-Path $ZipOut) { Remove-Item -Force $ZipOut }
if (Test-Path $SevenZipOut) { Remove-Item -Force $SevenZipOut }
New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
New-Item -ItemType Directory -Force -Path $NotebooksDir | Out-Null

if (Test-Path $OfflineInstaller) {
    $Installer = $OfflineInstaller
    Write-Host "==> Using cached installer: $Installer"
}
else {
    Write-Host "==> Downloading Python 3.8.10 installer..."
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
    Write-Host "    Silent install did not populate TargetDir (common if Python 3.8 is already registered). Falling back to copying an existing 3.8.10 tree..."
    if (Test-Path $PythonDir) { Remove-Item -Recurse -Force $PythonDir }

    $candidates = @()
    if ($env:PREBUILT_PYTHON38) { $candidates += $env:PREBUILT_PYTHON38.TrimEnd('\') }
    $candidates += (Join-Path $env:APPDATA "uv\python\cpython-3.8.10-windows-x86_64-none")
    $candidates += (Join-Path $env:LOCALAPPDATA "uv\python\cpython-3.8.10-windows-x86_64-none")
    $candidates += "D:\python3.8.10"
    $candidates += (Join-Path $env:LocalAppData "Programs\Python\Python38")
    $candidates += (Join-Path $ProjectRoot "python38")

    $copied = $false
    foreach ($src in $candidates) {
        if (-not $src) { continue }
        if (Test-Path $src) {
            Write-Host "    Trying copy from: $src"
            if (Copy-PythonTree -Source $src -Destination $PythonDir) {
                $ver = & (Join-Path $PythonDir "python.exe") -c "import platform; print(platform.python_version())"
                if ($ver -eq "3.8.10") {
                    $copied = $true
                    break
                }
                Write-Host "    Skipping (version $ver, need 3.8.10)"
                Remove-Item -Recurse -Force $PythonDir -ErrorAction SilentlyContinue
            }
        }
    }
    if (-not $copied) {
        throw @"
Could not place Python 3.8.10 into the bundle.
- On a clean PC, silent install should work.
- On a PC that already has Python 3.8, set PREBUILT_PYTHON38 to a folder that contains python.exe (3.8.10), e.g.:
  `$env:PREBUILT_PYTHON38='D:\python3.8.10'; .\build-portable-windows.ps1`
"@
    }
}

$PyExe = Join-Path $PythonDir "python.exe"
$pyVersion = & $PyExe -c "import platform; print(platform.python_version())"
if ($pyVersion -ne "3.8.10") {
    throw "Unexpected Python version in bundle: $pyVersion (expected 3.8.10)"
}

Write-Host "==> Installing pinned dependencies into portable python..."
if (Test-Path $WheelDir) {
    $env:PIP_NO_INDEX = "1"
    Remove-Item Env:PIP_INDEX_URL -ErrorAction SilentlyContinue
    Remove-Item Env:PIP_EXTRA_INDEX_URL -ErrorAction SilentlyContinue
    $pipBase = @("-m", "pip", "install", "--isolated", "--no-index", "--find-links", $WheelDir)
    Write-Host "    (offline wheels: $WheelDir)"
    & $PyExe @pipBase -r $ReqFile
    if ($LASTEXITCODE -ne 0) { throw "pip install requirements failed (exit $LASTEXITCODE)" }
}
else {
    Write-Host "    (PyPI - run prepare-offline-windows.ps1 -Profile $Profile first for reproducible offline builds)"
    Remove-Item Env:PIP_NO_INDEX -ErrorAction SilentlyContinue
    & $PyExe -m pip install --isolated -r $ReqFile
    if ($LASTEXITCODE -ne 0) { throw "pip install requirements failed (exit $LASTEXITCODE)" }
}

Write-Host "==> Writing launchers, log helper, and README.txt (ASCII only)..."
$logsDir = Join-Path $DistRoot "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
"" | Set-Content -LiteralPath (Join-Path $logsDir ".gitkeep") -Encoding Ascii

$jupyterRunCmd = @"
@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0.."
set "ROOT=%cd%"
set "PY=%ROOT%\runtime\python\python.exe"
set "NB=%ROOT%\runtime\notebooks"
set "JLOG=%ROOT%\logs\jupyter.log"
echo.>>"%ROOT%\logs\launcher.log" 2>nul
echo [%date% %time%] jupyter-run.cmd: starting notebook>>"%ROOT%\logs\launcher.log" 2>&1
"%PY%" -E -s -m notebook --notebook-dir="%NB%" 1>>"%JLOG%" 2>&1
set "JR=!errorlevel!"
echo [%date% %time%] jupyter-run.cmd: notebook process exited !JR!>>"%ROOT%\logs\launcher.log" 2>&1
endlocal
"@
Set-Content -LiteralPath (Join-Path $logsDir "jupyter-run.cmd") -Value $jupyterRunCmd -Encoding Ascii

$startBat = @"
@echo off
setlocal
cd /d "%~dp0"
set "LOGDIR=%~dp0logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
echo.>>"%LOGDIR%\launcher.log" 2>nul
echo [%date% %time%] START-Jupyter.bat: begin>>"%LOGDIR%\launcher.log" 2>&1

set "PY=%~dp0runtime\python\python.exe"
set "PYTHONHOME="
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"

for /f "tokens=4-5 delims=. " %%i in ('ver') do (
  set "WINMAJOR=%%i"
  set "WINMINOR=%%j"
)
if "$Profile"=="win10plus" (
  if not "%WINMAJOR%"=="10" (
    echo [%date% %time%] ERROR: not Windows 10/11, major=%WINMAJOR% minor=%WINMINOR%>>"%LOGDIR%\launcher.log" 2>&1
    echo ERROR: This package supports Windows 10/11 only. Current version is %WINMAJOR%.%WINMINOR%.
    pause
    exit /b 1
  )
)
if "$Profile"=="win7-legacy" (
  if "%WINMAJOR%"=="6" (
    if "%WINMINOR%" LSS "1" (
      echo [%date% %time%] ERROR: Windows version too old>>"%LOGDIR%\launcher.log" 2>&1
      echo ERROR: This package requires at least Windows 7.
      pause
      exit /b 1
    )
  )
)

if not exist "%PY%" (
  echo [%date% %time%] ERROR: bundled python.exe missing>>"%LOGDIR%\launcher.log" 2>&1
  echo ERROR: Bundled Python not found. Re-extract the full archive.
  pause
  exit /b 1
)

set "VFILE=%TEMP%\_jupyter_portable_ver_%RANDOM%%RANDOM%.tmp"
"%PY%" -E -s -c "import platform; print(platform.python_version())" 1>"%VFILE%" 2>nul
if not exist "%VFILE%" (
  echo [%date% %time%] ERROR: could not read Python version>>"%LOGDIR%\launcher.log" 2>&1
  echo ERROR: Could not run bundled Python to check version.
  pause
  exit /b 1
)
set "VER="
for /f "usebackq delims=" %%a in ("%VFILE%") do set "VER=%%a"
del "%VFILE%" >nul 2>&1
if not defined VER (
  echo [%date% %time%] ERROR: empty version from interpreter>>"%LOGDIR%\launcher.log" 2>&1
  echo ERROR: Empty Python version from bundled interpreter.
  pause
  exit /b 1
)
if not "%VER%"=="3.8.10" (
  echo [%date% %time%] ERROR: wrong Python version %VER%>>"%LOGDIR%\launcher.log" 2>&1
  echo ERROR: Wrong Python version: %VER% expected 3.8.10
  pause
  exit /b 1
)

echo [%date% %time%] checks OK, launching Jupyter (see logs\jupyter.log)>>"%LOGDIR%\launcher.log" 2>&1
echo Starting Jupyter Notebook...
echo Notebooks folder: %~dp0runtime\notebooks
echo Log files: %LOGDIR%\launcher.log  %LOGDIR%\jupyter.log
start "JupyterNotebook" /MIN cmd /c call "%~dp0logs\jupyter-run.cmd"
echo [%date% %time%] START-Jupyter.bat: jupyter worker started (separate process)>>"%LOGDIR%\launcher.log" 2>&1
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
Jupyter Exam - Windows portable bundle (Python 3.8.10, profile: $Profile)

How to use
1. Extract this folder anywhere (avoid non-ASCII paths if possible).
2. Double-click START-Jupyter.bat.
3. Put your .ipynb files in runtime\notebooks (default notebook dir).

Notes
- Python 3.8.10 and libraries are bundled; you do not need a system Python.
- Logs: logs\launcher.log (startup steps) and logs\jupyter.log (Jupyter server output).
- If startup fails, run SELFTEST.bat and read the error, then check logs\launcher.log.
- Do not delete or rename the runtime folder.

Teachers: rebuild with .\build-portable-windows.ps1 -Profile $Profile
"@
Set-Content -LiteralPath (Join-Path $DistRoot "README.txt") -Value $readme -Encoding Ascii

"" | Set-Content -LiteralPath (Join-Path $NotebooksDir ".gitkeep") -Encoding ASCII

$sevenZipExe = Find-SevenZip
if ($sevenZipExe) {
    Write-Host "==> Creating 7z archive with 7-Zip (may take several minutes)..."
    Push-Location -LiteralPath $DistRoot
    try {
        & $sevenZipExe @("a", "-t7z", "-mx=9", "-y", $SevenZipOut, "*")
        if ($LASTEXITCODE -ne 0) {
            throw "7z failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "==> 7-Zip (7z.exe) not found; creating ZIP instead (install 7-Zip for smaller .7z output)..."
    Compress-Archive -Path (Join-Path $DistRoot "*") -DestinationPath $ZipOut -Force
}

if (Test-Path $TmpInstaller) {
    Remove-Item -Force $TmpInstaller -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done."
Write-Host "  Folder: $DistRoot"
if (Test-Path -LiteralPath $SevenZipOut) {
    Write-Host "  7Z:     $SevenZipOut"
}
if (Test-Path -LiteralPath $ZipOut) {
    Write-Host "  ZIP:    $ZipOut"
}
Write-Host "Students: extract archive, double-click START-Jupyter.bat (see README.txt)"
