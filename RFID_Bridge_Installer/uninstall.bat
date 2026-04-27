@echo off
:: ============================================================
::  Warehouse Fitness — RFID Bridge Uninstaller
:: ============================================================
setlocal
title RFID Bridge — Uninstaller

net session >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Please right-click and choose "Run as administrator"
    pause & exit /b 1
)

set INSTALL_DIR=C:\RFIDBridge
set TASK_NAME=WarehouseFitness_RFIDBridge

echo.
echo  ============================================
echo   Warehouse Fitness RFID Bridge — Uninstall
echo  ============================================
echo.
set /p CONFIRM=  Are you sure you want to uninstall? (Y/N): 
if /i not "%CONFIRM%"=="Y" (
    echo  Cancelled.
    pause & exit /b 0
)

echo.
echo  [1/3] Stopping RFID Bridge process...
taskkill /f /im rfid_bridge.exe >nul 2>&1
echo  [OK] Process stopped

echo  [2/3] Removing scheduled task...
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
echo  [OK] Task removed

echo  [3/3] Deleting install folder...
if exist "%INSTALL_DIR%" rd /s /q "%INSTALL_DIR%"
echo  [OK] Files removed

echo.
echo  ============================================
echo   Uninstall complete.
echo  ============================================
echo.
pause
