@echo off
setlocal
title Odysseus - Workspace AI (Docker)
set "DOCKER=C:\Program Files\Docker\Docker\resources\bin\docker.exe"
set "DD=C:\Program Files\Docker\Docker\Docker Desktop.exe"
set "URL=http://localhost:7000"
set "PROFILE=%LocalAppData%\OdysseusApp"
cd /d C:\Odysseus
cls
echo.
echo    ============================================
echo       ODYSSEUS - Workspace AI (Docker)
echo    ============================================
echo.

rem --- S'assurer que Docker Desktop tourne ---
"%DOCKER%" info >nul 2>&1
if errorlevel 1 (
    echo    Demarrage de Docker Desktop...
    start "" "%DD%"
    echo    Attente du moteur Docker ^(jusqu'a 90s^)...
    for /l %%i in (1,1,30) do (
        timeout /t 3 >nul
        "%DOCKER%" info >nul 2>&1
        if not errorlevel 1 goto :ready
    )
    echo    [!] Docker n'a pas demarre a temps. Ouvre Docker Desktop manuellement.
    pause
    exit /b 1
)
:ready
echo    Moteur Docker pret.
echo.
echo    Demarrage de la stack Odysseus...
"%DOCKER%" compose up -d
echo.
echo    Attente du chargement d'Odysseus...
rem --- Attendre que le port 7000 reponde vraiment (max ~40s) ---
for /l %%i in (1,1,40) do (
    powershell -NoProfile -Command "try { $r=Invoke-WebRequest -Uri '%URL%' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
    if not errorlevel 1 goto :appready
    timeout /t 1 >nul
)
:appready
echo    Odysseus pret. Ouverture de la fenetre...

rem --- Detecter le navigateur ---
set "BROWSER="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "BROWSER=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "BROWSER=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "BROWSER=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "BROWSER=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not defined BROWSER if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "BROWSER=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"

if defined BROWSER (
    rem Profil dedie => la fenetre garde sa taille et sa position entre les lancements
    start "" "%BROWSER%" --app=%URL% --user-data-dir="%PROFILE%" --no-first-run --no-default-browser-check
) else (
    start %URL%
)
echo.
echo    ============================================
echo     Odysseus tourne sur %URL%
echo     Login : admin
echo.
echo     Les conteneurs tournent en arriere-plan.
echo     Pour les ARRETER : lance Odysseus-Stop.bat
echo    ============================================
echo.
timeout /t 3 >nul
endlocal