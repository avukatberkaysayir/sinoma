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

:: Start emulator in background, wait a bit, then seed data
start /b firebase emulators:start --project demo-mandarin-academy --only auth,firestore,hosting

echo  Waiting for emulators to start...
timeout /t 10 /nobreak > nul

echo.
echo  3.  Seeding demo data...
dart run tool/seed_emulator.dart

echo.
echo  4.  Starting Pipeline dev server (port 9302)...
echo      Admin panel "Process" button uses this server.
start "Pipeline Server" cmd /k "cd /d %~dp0python && python pipeline/dev_server.py"
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
