@echo off
rem CFE-4701: dump each LMDB database with the old mdb_dump (saved aside as
rem mdb_dump-old.exe by the LmdbSaveDumper custom action) and load it with the
rem new mdb_load. Run from LmdbMigrate, after InstallFiles. Probes each database
rem rather than comparing versions -- easier than version parsing in batch.
rem Best-effort: on failure CFEngine just recreates the database.

setlocal
set "BIN=%~dp0"
set "WORK=%BIN%.."
set "OLDDUMP=%BIN%mdb_dump-old.exe"
set "NEWDUMP=%BIN%mdb_dump.exe"
set "NEWLOAD=%BIN%mdb_load.exe"
set "LOG=%WORK%\lmdb-migrate.log"

rem No saved dumper means this is not an upgrade across a format change.
if not exist "%OLDDUMP%" exit /b 0
if not exist "%NEWDUMP%" exit /b 0
if not exist "%NEWLOAD%" exit /b 0

echo [%DATE% %TIME%] lmdb-migrate: starting>>"%LOG%"

rem State dir, plus the workdir for pre-3.7 installs.
for %%D in ("%WORK%\state\*.lmdb" "%WORK%\*.lmdb") do call :migrate_one "%%~fD"

del /f /q "%OLDDUMP%" >nul 2>&1
echo [%DATE% %TIME%] lmdb-migrate: done>>"%LOG%"
endlocal
exit /b 0

:migrate_one
set "DB=%~1"

rem Readable by the new library already? Then leave it alone.
"%NEWDUMP%" -n "%DB%" >nul 2>&1
if not errorlevel 1 exit /b 0

"%OLDDUMP%" -n -f "%DB%.dump" "%DB%" >nul 2>&1
if errorlevel 1 (
    rem Corrupt or uninitialised: leave it to cf-check.
    del /f /q "%DB%.dump" >nul 2>&1
    echo   could not export "%DB%", it will be recreated empty>>"%LOG%"
    exit /b 0
)

"%NEWLOAD%" -n -f "%DB%.dump" "%DB%.new" >nul 2>&1
if errorlevel 1 (
    del /f /q "%DB%.new" "%DB%.new-lock" >nul 2>&1
    echo   could not import "%DB%", it will be recreated empty>>"%LOG%"
    echo   exported data kept in "%DB%.dump">>"%LOG%"
    exit /b 0
)

rem Overwrite rather than replace, so the original file's ACL survives.
copy /y "%DB%.new" "%DB%" >nul 2>&1
if errorlevel 1 (
    del /f /q "%DB%.new" "%DB%.new-lock" >nul 2>&1
    echo   could not write "%DB%", it will be recreated empty>>"%LOG%"
    echo   exported data kept in "%DB%.dump">>"%LOG%"
    exit /b 0
)

rem The lock file carries its own format version.
del /f /q "%DB%.new" "%DB%.new-lock" "%DB%-lock" "%DB%.dump" >nul 2>&1
echo   imported "%DB%">>"%LOG%"
exit /b 0
