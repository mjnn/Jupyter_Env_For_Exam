@echo off
setlocal
set "ROOT=%~dp0"
set "PY=%ROOT%.venv38\Scripts\python.exe"
set "PYTHONHOME="
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"

if not exist "%PY%" (
  echo Environment not found. Run bootstrap-windows.ps1 first.
  pause
  exit /b 1
)

set "VFILE=%TEMP%\_jupyter_venv_ver_%RANDOM%%RANDOM%.tmp"
"%PY%" -E -s -c "import platform; print(platform.python_version())" 1>"%VFILE%" 2>nul
if not exist "%VFILE%" (
  echo Could not read Python version.
  pause
  exit /b 1
)
set "VER="
for /f "usebackq delims=" %%a in ("%VFILE%") do set "VER=%%a"
del "%VFILE%" >nul 2>&1
if not "%VER%"=="3.8.10" (
  echo Python version mismatch in .venv38: %VER%
  pause
  exit /b 1
)

echo Starting Jupyter Notebook...
"%PY%" -E -s -m notebook

endlocal
