@echo off
title Mandarin Academy — Dev Environment
setlocal

set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-21.0.11.10-hotspot
set PATH=%JAVA_HOME%\bin;%PATH%

cd /d %~dp0

echo.
echo  Mandarin Academy — Dev Environment
echo  ════════════════════════════════════════════

:: Kill leftover processes
taskkill /f /im java.exe  >nul 2>&1
taskkill /f /im dartvm.exe >nul 2>&1
timeout /t 3 /nobreak >nul

:: ── 1. Firebase Emulators (background, log → emulator.log) ───────────────
echo  1.  Starting Firebase Emulators (auth + firestore)...
if exist emulator-data\ (
    start "" /b "C:\Users\berka\AppData\Roaming\npm\firebase.cmd" emulators:start --project demo-mandarin-academy --only auth,firestore --import=emulator-data --export-on-exit=emulator-data > emulator.log 2>&1
) else (
    start "" /b "C:\Users\berka\AppData\Roaming\npm\firebase.cmd" emulators:start --project demo-mandarin-academy --only auth,firestore --export-on-exit=emulator-data > emulator.log 2>&1
)

:: ── 2. Pipeline server ────────────────────────────────────────────────────
echo  2.  Starting Pipeline server (port 9302)...
start "Pipeline" /b py "%~dp0python\pipeline\dev_server.py" > pipeline.log 2>&1

:: ── 3. Flutter dev server ─────────────────────────────────────────────────
echo  3.  Starting Flutter dev server (port 9300)...
start "Flutter Dev Server  [r=reload  R=restart]" cmd /k "cd /d %~dp0 && flutter run -d web-server --web-port 9300 --web-hostname localhost"

:: ── Wait for Flutter then open browser ───────────────────────────────────
echo  Waiting for Flutter to compile (~30s)...
set /a n=0
:wait
timeout /t 3 /nobreak >nul
set /a n+=1
powershell -command "try{$null=(New-Object Net.WebClient).DownloadString('http://localhost:9300');exit 0}catch{exit 1}" >nul 2>&1
if not errorlevel 1 goto :done
if %n% geq 40 goto :done
goto :wait

:done
start "" "http://localhost:9300"
echo.
echo  http://localhost:9300  ^<-- App
echo  http://localhost:4001  ^<-- Emulator UI (may take 60s)
echo  Emulator log: %~dp0emulator.log
echo.
pause
