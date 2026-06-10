@echo off
title Odysseus - Update
set "DOCKER=C:\Program Files\Docker\Docker\resources\bin\docker.exe"
set "GIT=C:\Program Files\Git\cmd\git.exe"
cd /d C:\Odysseus

echo Backup data (hors modeles GGUF)...
powershell -NoProfile -Command "$d='C:\Odysseus\data'; $items=Get-ChildItem $d -Force | Where-Object { $_.Name -ne 'local' -and $_.Name -ne 'huggingface' }; if($items){ Compress-Archive -Path $items.FullName -DestinationPath ('C:\Odysseus_data_backup_'+(Get-Date -Format 'yyyy-MM-dd_HHmmss')+'.zip') -Force } else { Write-Host 'rien a sauvegarder' }"

echo Arret stack...
"%DOCKER%" compose stop

echo Recuperation du code...
"%GIT%" pull
if errorlevel 1 goto pullfail

echo Rebuild...
"%DOCKER%" compose up -d --build
if errorlevel 1 goto buildfail

echo.
echo Update terminee. Tes deps cookbook dans data/local sont conservees.
pause
exit /b 0

:pullfail
echo.
echo *** ECHEC GIT PULL - code NON mis a jour. Relance de l'ancienne stack... ***
"%DOCKER%" compose up -d
echo Resous les changements locaux (git status) puis relance la mise a jour.
pause
exit /b 1

:buildfail
echo.
echo *** ECHEC DU REBUILD - verifie Docker Desktop. ***
pause
exit /b 1
