@echo off
title Mandarin Academy — Dev Environment

:: ── Java 21 (required by Firebase Emulator) ──────────────────────────────
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-21.0.11.10-hotspot
set PATH=%JAVA_HOME%\bin;%PATH%

echo.
echo  Mandarin Academy — Dev Environment
echo  ════════════════════════════════════════════
echo  1.  Building Flutter web (debug)...
echo.

cd /d %~dp0
call flutter build web --debug --no-pub

echo.
echo  2.  Starting Firebase Emulators...
echo      Auth     → http://localhost:9199
echo      Firestore→ http://localhost:9299
echo      Hosting  → http://localhost:9300
echo      UI       → http://localhost:4001
echo.

:: --import restores saved data; --export-on-exit saves data on shutdown
:: First run: emulator-data/ won't exist → emulator starts empty (then seeded)
:: Subsequent runs: emulator-data/ exists → previous data is restored (seed skipped)
if exist emulator-data\ (
    echo  [INFO] Restoring saved emulator data from emulator-data\
    start /b firebase emulators:start --project demo-mandarin-academy --only auth,firestore,hosting --import=emulator-data --export-on-exit=emulator-data
) else (
    start /b firebase emulators:start --project demo-mandarin-academy --only auth,firestore,hosting --export-on-exit=emulator-data
)

echo  Waiting for emulators to start...
timeout /t 12 /nobreak > nul

:: Only seed if this is the first run (no saved data)
if not exist emulator-data\ (
    echo.
    echo  3.  Seeding demo data...
    dart run tool/seed_emulator.dart
) else (
    echo  3.  Skipping seed — restored from emulator-data\
)

echo.
echo  4.  Starting Pipeline dev server (port 9302)...
echo      Admin panel "Process" button uses this server.
start "Pipeline Server" cmd /k "cd /d %~dp0python && py pipeline/dev_server.py"
timeout /t 2 /nobreak > nul

echo.
echo  ════════════════════════════════════════════
echo  App is ready!
echo.
echo  Open in browser:    http://localhost:9300
echo  Emulator UI:        http://localhost:4001
echo  Pipeline server:    http://localhost:9302
echo  ════════════════════════════════════════════
echo.
pause
