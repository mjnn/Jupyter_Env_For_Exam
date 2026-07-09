@echo off
setlocal
set "ROOT=%~dp0"
set "PY=%ROOT%.venv38\Scripts\python.exe"
set "LOGDIR=%ROOT%logs"
set "PYTHONHOME="
set "PYTHONPATH="
set "PYTHONNOUSERSITE=1"

if not exist "%LOGDIR%" mkdir "%LOGDIR%"
echo.>>"%LOGDIR%\launcher.log" 2>nul
echo [%date% %time%] launch-jupyter-windows.bat: begin>>"%LOGDIR%\launcher.log" 2>&1

if not exist "%PY%" (
  echo [%date% %time%] ERROR: venv not found>>"%LOGDIR%\launcher.log" 2>&1
  echo Environment not found. Run bootstrap-windows.ps1 first.
  pause
  exit /b 1
)

set "VFILE=%TEMP%\_jupyter_venv_ver_%RANDOM%%RANDOM%.tmp"
"%PY%" -E -s -c "import platform; print(platform.python_version())" 1>"%VFILE%" 2>nul
if not exist "%VFILE%" (
  echo [%date% %time%] ERROR: could not read Python version>>"%LOGDIR%\launcher.log" 2>&1
  echo Could not read Python version.
  pause
  exit /b 1
)
set "VER="
for /f "usebackq delims=" %%a in ("%VFILE%") do set "VER=%%a"
del "%VFILE%" >nul 2>&1
if not "%VER%"=="3.8.10" (
  echo [%date% %time%] ERROR: version mismatch %VER%>>"%LOGDIR%\launcher.log" 2>&1
  echo Python version mismatch in .venv38: %VER%
  pause
  exit /b 1
)

echo [%date% %time%] starting notebook, log: %LOGDIR%\jupyter.log>>"%LOGDIR%\launcher.log" 2>&1
echo Starting Jupyter Notebook (logging to %LOGDIR%\jupyter.log)...
cd /d "%ROOT%"
"%PY%" -E -s -m notebook 1>>"%LOGDIR%\jupyter.log" 2>&1
echo [%date% %time%] notebook process exited %errorlevel%>>"%LOGDIR%\launcher.log" 2>&1

endlocal
