@echo off
rem Update this repo from GitHub, copy leRep into the WoW: Forever client, and pack
rem leRep-<version>.zip on the desktop. Run it from a terminal (from any folder), then restart the
rem client, or /reload if leRep was already loaded. It only pulls what's on GitHub: push your commits
rem first.
setlocal

rem git pull can update this very file, and cmd reads a running script from disk line by line, so
rem the script runs from a temporary copy. The original folder is passed along as the second argument.
if not "%~1"=="--copy" (
  copy /y "%~f0" "%TEMP%\lerep_install.cmd" >nul
  call "%TEMP%\lerep_install.cmd" --copy "%~dp0"
  exit /b
)

rem The repo is the folder above this script's tools folder, so it keeps working if the repo is
rem renamed or moved.
for %%i in ("%~2..") do set "REPO=%%~fi"
rem Change WOW if your client lives elsewhere (for example the _classic_beta_ folder).
rem Inside ( ) blocks, always quote paths: the ) in "Program Files (x86)" would end the block.
set "WOW=C:\Program Files (x86)\World of Warcraft\_forever_"
set "ADDONS=%WOW%\Interface\AddOns"
set "RESULT=0"
set "RESTART=0"
set "LIST="

if not exist "%REPO%\leRep\leRep.toc" (
  echo Can't find the addon in "%REPO%\leRep". Is this script in the repo's tools folder?
  set "RESULT=1"
  goto done
)
if not exist "%WOW%\" (
  echo Can't find the WoW client at "%WOW%". Fix WOW at the top of this script.
  set "RESULT=1"
  goto done
)

git -C "%REPO%" pull --ff-only
if errorlevel 1 (
  rem The usual reason: the history on GitHub was rewritten, so this copy can't simply move
  rem forward. If this copy's last commit isn't in GitHub's history any more, say how to fix it.
  git -C "%REPO%" fetch origin --tags --force >nul 2>&1
  rem merge-base exits 1 when this copy's commit isn't in GitHub's history, 128 when it can't tell.
  git -C "%REPO%" merge-base --is-ancestor HEAD "@{u}" >nul 2>&1
  if errorlevel 128 (
    echo git pull failed, so nothing was copied.
  ) else if errorlevel 1 (
    echo This copy and GitHub have different histories, usually because GitHub's was rewritten.
    echo To move this copy onto GitHub's, run these two commands, then this script again.
    echo They throw away commits and edits made in this copy that aren't on GitHub.
    echo   git -C "%REPO%" fetch origin --tags --force
    echo   git -C "%REPO%" reset --hard origin/main
  ) else (
    echo git pull failed, so nothing was copied.
  )
  set "RESULT=1"
  goto done
)

rem Earlier builds were installed as "LeRep" or "Lerep". Windows ignores letter case, so copying over
rem such a folder would keep its old spelling, which is the addon's name in game: remove it first.
rem findstr /i finds every spelling; "if" compares with case, so only the wrong ones go.
for /f "delims=" %%d in ('dir /b /ad "%ADDONS%" 2^>nul ^| findstr /x /i /c:"leRep"') do (
  if not "%%d"=="leRep" (
    echo Removing the old "%%d" folder: leRep replaces it.
    rmdir /s /q "%ADDONS%\%%d"
  )
)

call :install leRep
if "%RESULT%"=="1" goto done

rem Stamp the installed addon with the commit, so /lerep help shows which build is running.
rem "-dirty" means the copy includes changes that aren't committed.
for /f %%h in ('git -C "%REPO%" rev-parse --short HEAD') do set "BUILD=%%h"
for /f %%s in ('git -C "%REPO%" status --porcelain -- leRep') do set "BUILD=%BUILD%-dirty"
> "%ADDONS%\leRep\Build.lua" (
  echo local _, ns = ...
  echo ns.build = "%BUILD%"
)
echo Installed build %BUILD%:%LIST%

rem Also pack the committed addon as leRep-<version>.zip on the desktop, ready to share or upload.
rem git archive takes only committed files (without the build stamp above). The version is
rem ## Version in leRep.toc. The desktop comes from Windows, since OneDrive can move it.
set "VERSION="
for /f "tokens=3" %%v in ('findstr /b /c:"## Version:" "%REPO%\leRep\leRep.toc"') do set "VERSION=%%v"
set "DESKTOP=%USERPROFILE%\Desktop"
for /f "usebackq delims=" %%d in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%d"
if "%VERSION%"=="" (
  echo No ## Version in leRep.toc, so no zip was made.
) else (
  git -C "%REPO%" archive --format=zip --output="%DESKTOP%\leRep-%VERSION%.zip" HEAD %LIST%
  if errorlevel 1 (
    echo Couldn't write "%DESKTOP%\leRep-%VERSION%.zip".
  ) else (
    echo Packed "%DESKTOP%\leRep-%VERSION%.zip" from the last commit.
  )
)
if "%RESTART%"=="1" (
  echo An addon's file list changed: fully restart the game, /reload won't load new files.
  echo Then /lerep help should say build %BUILD%.
) else (
  echo In game: /reload, then /lerep help should say build %BUILD%.
)
goto done

rem Copies one addon folder into AddOns. Sets RESTART when its .toc changed (WoW reads an addon's
rem file list only when the game starts) and RESULT on failure.
:install
set "NAME=%~1"
if not exist "%REPO%\%NAME%\%NAME%.toc" exit /b 0
set "TARGET=%ADDONS%\%NAME%"
if not exist "%TARGET%\" (
  echo Creating "%TARGET%"
  mkdir "%TARGET%"
  if errorlevel 1 (
    echo Couldn't create the folder. Is the WoW folder writable? Try running this as administrator.
    set "RESULT=1"
    exit /b 1
  )
)
if exist "%TARGET%\%NAME%.toc" (
  fc /b "%REPO%\%NAME%\%NAME%.toc" "%TARGET%\%NAME%.toc" >nul || set "RESTART=1"
) else (
  set "RESTART=1"
)
rem /MIR makes the installed folder an exact copy (files no longer in the repo are deleted).
robocopy "%REPO%\%NAME%" "%TARGET%" /MIR /IS /IT /NJH /NJS /NDL /NFL /NP >nul
rem robocopy exit codes below 8 mean success.
if errorlevel 8 (
  echo Copying %NAME% failed. Is the WoW folder writable, and the path above right?
  set "RESULT=1"
  exit /b 1
)
set "LIST=%LIST% %NAME%"
exit /b 0

:done
exit /b %RESULT%
