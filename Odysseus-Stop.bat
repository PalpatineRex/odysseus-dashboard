@echo off
title Odysseus - Arret
set "DOCKER=C:\Program Files\Docker\Docker\resources\bin\docker.exe"
cd /d C:\Odysseus
cls
echo.
echo    Arret de la stack Odysseus...
"%DOCKER%" compose stop
echo.
echo    Odysseus est arrete. ^(Docker Desktop continue de tourner.^)
echo.
timeout /t 3 >nul