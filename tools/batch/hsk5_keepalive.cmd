@echo off
REM Sinoma HSK-5 drain keep-alive. Runs at logon (copied into the Startup folder)
REM and loops every 20 min: each tick the supervisor starts the resumable driver
REM if it died and the pending pool is non-empty. When the pool empties the
REM supervisor exits 2 and this loop stops. Survives reboots (Startup) and
REM mid-session crashes (loop). No admin required.
:loop
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\github\Sinoma\tools\batch\hsk5_supervisor.ps1"
if %ERRORLEVEL%==2 goto done
timeout /t 1200 /nobreak >nul
goto loop
:done
echo HSK5 drain tamam — keepalive duruyor.
