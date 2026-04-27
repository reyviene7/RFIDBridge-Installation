@echo off
:: ============================================================
::  Warehouse Fitness — RFID Bridge Builder
::  Double-click to run. Does NOT need Administrator.
:: ============================================================
setlocal enabledelayedexpansion
title RFID Bridge — Build Tool

:: ── Force working directory to where this .bat lives ────────
cd /d "%~dp0"

echo.
echo  ============================================
echo   Warehouse Fitness RFID Bridge - Builder
echo  ============================================
echo.

:: ── Warn if running as Admin (PyInstaller dislikes it) ───────
net session >nul 2>&1
if not errorlevel 1 (
    echo  [WARN] You are running as Administrator.
    echo         PyInstaller works better without admin rights.
    echo         If the build fails, close this and double-click
    echo         build.bat WITHOUT right-clicking "Run as admin".
    echo.
)

:: ── Check Python ─────────────────────────────────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Python not found. Install Python 3.10+ from python.org
    echo          Make sure "Add Python to PATH" is checked during install.
    pause & exit /b 1
)
for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PYVER=%%v
echo  [OK] Python %PYVER% found

:: ── Install build dependencies ───────────────────────────────
echo.
echo  [1/4] Installing dependencies...
python -m pip install pyinstaller pyserial httpx python-dotenv --quiet --no-warn-script-location
if errorlevel 1 (
    echo  [ERROR] pip install failed.
    pause & exit /b 1
)
echo  [OK] Dependencies installed

:: ── Build EXE ────────────────────────────────────────────────
echo.
echo  [2/4] Building standalone EXE (this takes ~60 seconds)...

:: Must cd into src so PyInstaller finds rfid_bridge.py correctly
cd /d "%~dp0src"
echo  [INFO] Working directory: %CD%

:: Use python -m pyinstaller instead of bare pyinstaller command
:: This avoids the System32 PATH issue entirely
python -m PyInstaller ^
    --onefile ^
    --console ^
    --name "rfid_bridge" ^
    --hidden-import serial ^
    --hidden-import serial.tools ^
    --hidden-import serial.tools.list_ports ^
    --hidden-import httpx ^
    --hidden-import dotenv ^
    --hidden-import asyncio ^
    --hidden-import msvcrt ^
    --distpath "%~dp0dist" ^
    --workpath "%~dp0build_tmp" ^
    --specpath "%~dp0build_tmp" ^
    rfid_bridge.py

if errorlevel 1 (
    echo.
    echo  [ERROR] PyInstaller build failed.
    echo          Read the error above carefully.
    cd /d "%~dp0"
    pause & exit /b 1
)

cd /d "%~dp0"
echo  [OK] EXE built: dist\rfid_bridge.exe

:: ── Assemble installer package ───────────────────────────────
echo.
echo  [3/4] Assembling installer package...

if exist "RFID_Bridge_Installer" rd /s /q "RFID_Bridge_Installer"
mkdir "RFID_Bridge_Installer"

:: Verify EXE actually exists before copying
if not exist "dist\rfid_bridge.exe" (
    echo  [ERROR] EXE not found at dist\rfid_bridge.exe - build may have silently failed.
    pause & exit /b 1
)

copy /y "dist\rfid_bridge.exe"    "RFID_Bridge_Installer\rfid_bridge.exe"  >nul
copy /y "src\.env.template"       "RFID_Bridge_Installer\.env.template"    >nul
copy /y "install.bat"             "RFID_Bridge_Installer\install.bat"      >nul
copy /y "uninstall.bat"           "RFID_Bridge_Installer\uninstall.bat"    >nul
copy /y "README.txt"              "RFID_Bridge_Installer\README.txt"       >nul

echo  [OK] Package assembled in: RFID_Bridge_Installer\

:: ── Zip the package ──────────────────────────────────────────
echo.
echo  [4/4] Creating ZIP archive...
if exist "RFID_Bridge_Installer.zip" del "RFID_Bridge_Installer.zip"

powershell -NoProfile -Command ^
    "Compress-Archive -Path 'RFID_Bridge_Installer\*' -DestinationPath 'RFID_Bridge_Installer.zip' -Force"

if errorlevel 1 (
    echo  [WARN] Could not create ZIP automatically.
    echo         Manually zip the "RFID_Bridge_Installer" folder.
) else (
    echo  [OK] RFID_Bridge_Installer.zip ready!
)

:: ── Cleanup temp build files ──────────────────────────────────
if exist "build_tmp" rd /s /q "build_tmp" >nul 2>&1

echo.
echo  ============================================
echo   BUILD COMPLETE
echo.
echo   Installer folder : RFID_Bridge_Installer\
echo   ZIP to send      : RFID_Bridge_Installer.zip
echo.
echo   Send the ZIP to the client.
echo   Client extracts it and runs install.bat
echo   as Administrator.
echo  ============================================
echo.
pause
