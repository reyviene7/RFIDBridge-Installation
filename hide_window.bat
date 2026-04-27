@echo off
:: ============================================================
::  Warehouse Fitness — Hide RFID Bridge Window
::  Run as Administrator to make the bridge invisible.
:: ============================================================
setlocal
title RFID Bridge — Hide Window Tool

net session >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Please right-click and choose "Run as administrator"
    pause & exit /b 1
)

set TASK_NAME=WarehouseFitness_RFIDBridge
set INSTALL_DIR=C:\RFIDBridge
set VBS_PATH=%INSTALL_DIR%\run_hidden.vbs

echo.
echo  ============================================
echo   Warehouse Fitness RFID Bridge
echo   Hide Window Setup
echo  ============================================
echo.

:: ── Step 1: Create a VBScript launcher that runs with no window ──
echo  [1/3] Creating hidden launcher...
(
    echo Set WshShell = CreateObject^("WScript.Shell"^)
    echo WshShell.Run """%INSTALL_DIR%\rfid_bridge.exe""", 0, False
) > "%VBS_PATH%"
echo  [OK] Hidden launcher created: %VBS_PATH%

:: ── Step 2: Delete old task ───────────────────────────────────
echo.
echo  [2/3] Updating Task Scheduler...
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

:: ── Step 3: Recreate task using the VBS hidden launcher ───────
set XML_PATH=%TEMP%\rfid_task_hidden.xml
(
echo ^<?xml version="1.0" encoding="UTF-16"?^>
echo ^<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo   ^<RegistrationInfo^>
echo     ^<Description^>Warehouse Fitness RFID Bridge Service^</Description^>
echo   ^</RegistrationInfo^>
echo   ^<Triggers^>
echo     ^<BootTrigger^>
echo       ^<Enabled^>true^</Enabled^>
echo       ^<Delay^>PT30S^</Delay^>
echo     ^</BootTrigger^>
echo   ^</Triggers^>
echo   ^<Principals^>
echo     ^<Principal id="Author"^>
echo       ^<LogonType^>InteractiveToken^</LogonType^>
echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
echo     ^</Principal^>
echo   ^</Principals^>
echo   ^<Settings^>
echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
echo     ^<Hidden^>true^</Hidden^>
echo     ^<RestartOnFailure^>
echo       ^<Interval^>PT1M^</Interval^>
echo       ^<Count^>999^</Count^>
echo     ^</RestartOnFailure^>
echo   ^</Settings^>
echo   ^<Actions^>
echo     ^<Exec^>
echo       ^<Command^>wscript.exe^</Command^>
echo       ^<Arguments^>"%VBS_PATH%"^</Arguments^>
echo       ^<WorkingDirectory^>%INSTALL_DIR%^</WorkingDirectory^>
echo     ^</Exec^>
echo   ^</Actions^>
echo ^</Task^>
) > "%XML_PATH%"

schtasks /create /tn "%TASK_NAME%" /xml "%XML_PATH%" /f >nul
if errorlevel 1 (
    echo  [ERROR] Failed to update task.
    del "%XML_PATH%" >nul 2>&1
    pause & exit /b 1
)
del "%XML_PATH%" >nul 2>&1
echo  [OK] Task updated to run hidden

:: ── Step 4: Kill current visible window and relaunch hidden ───
echo.
echo  [3/3] Restarting bridge as hidden process...
taskkill /f /im rfid_bridge.exe >nul 2>&1
timeout /t 2 >nul
wscript.exe "%VBS_PATH%"
timeout /t 2 >nul

:: ── Verify it's running ───────────────────────────────────────
tasklist /fi "imagename eq rfid_bridge.exe" 2>nul | find /i "rfid_bridge.exe" >nul
if errorlevel 1 (
    echo  [WARN] Process not detected yet - it may still be starting.
    echo         Check C:\RFIDBridge\rfid_bridge.log to confirm.
) else (
    echo  [OK] rfid_bridge.exe is running silently in background!
)

echo.
echo  ============================================
echo   DONE! The RFID Bridge now runs completely
echo   hidden. No window will appear on boot.
echo.
echo   To check if it's running:
echo     - Open Task Manager ^> Details tab
echo     - Look for rfid_bridge.exe
echo.
echo   To read the log:
echo     C:\RFIDBridge\rfid_bridge.log
echo.
echo   To stop it manually:
echo     taskkill /f /im rfid_bridge.exe
echo  ============================================
echo.
pause
