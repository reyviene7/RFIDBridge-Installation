@echo off
:: ============================================================
::  Warehouse Fitness — RFID Bridge Builder
::  Run this on YOUR machine to produce the installer package.
::  Requires: Python 3.10+, pip
:: ============================================================
setlocal enabledelayedexpansion
title RFID Bridge — Build Tool

echo.
echo  ============================================
echo   Warehouse Fitness RFID Bridge — Builder
echo  ============================================
echo.

:: ── Check Python ────────────────────────────────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Python not found. Install Python 3.10+ from python.org
    pause & exit /b 1
)
for /f "tokens=2 delims= " %%v in ('python --version') do set PYVER=%%v
echo  [OK] Python %PYVER% found

:: ── Install build dependencies ───────────────────────────────
echo.
echo  [1/4] Installing dependencies...
pip install pyinstaller pyserial httpx python-dotenv --quiet
if errorlevel 1 (
    echo  [ERROR] pip install failed.
    pause & exit /b 1
)
echo  [OK] Dependencies installed

:: ── Build EXE ────────────────────────────────────────────────
echo.
echo  [2/4] Building standalone EXE (this takes ~60 seconds)...
cd /d "%~dp0src"

pyinstaller ^
    --onefile ^
    --console ^
    --name "rfid_bridge" ^
    --hidden-import serial ^
    --hidden-import httpx ^
    --hidden-import dotenv ^
    --hidden-import asyncio ^
    --hidden-import msvcrt ^
    rfid_bridge.py

if errorlevel 1 (
    echo  [ERROR] PyInstaller build failed. Check output above.
    cd /d "%~dp0"
    pause & exit /b 1
)
echo  [OK] EXE built successfully

:: ── Assemble installer package ───────────────────────────────
echo.
echo  [3/4] Assembling installer package...
cd /d "%~dp0"

if exist "RFID_Bridge_Installer" rd /s /q "RFID_Bridge_Installer"
mkdir "RFID_Bridge_Installer"

:: Copy EXE
copy "src\dist\rfid_bridge.exe"   "RFID_Bridge_Installer\rfid_bridge.exe"   >nul
:: Copy template .env
copy "src\.env.template"          "RFID_Bridge_Installer\.env.template"      >nul
:: Copy install script
copy "install.bat"                "RFID_Bridge_Installer\install.bat"        >nul
:: Copy uninstall script
copy "uninstall.bat"              "RFID_Bridge_Installer\uninstall.bat"      >nul
:: Copy README
copy "README.txt"                 "RFID_Bridge_Installer\README.txt"         >nul

echo  [OK] Package assembled in: RFID_Bridge_Installer\

:: ── Zip the package ──────────────────────────────────────────
echo.
echo  [4/4] Creating ZIP archive...
powershell -Command ^
    "Compress-Archive -Path 'RFID_Bridge_Installer\*' -DestinationPath 'RFID_Bridge_Installer.zip' -Force"
if errorlevel 1 (
    echo  [WARN] Could not create ZIP. Folder is still ready to copy manually.
) else (
    echo  [OK] RFID_Bridge_Installer.zip created!
)

echo.
echo  ============================================
echo   BUILD COMPLETE
echo   Send "RFID_Bridge_Installer.zip" to client
echo   Client runs "install.bat" inside the ZIP
echo  ============================================
echo.
pause
