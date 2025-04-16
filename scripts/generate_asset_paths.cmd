@echo off
setlocal enabledelayedexpansion

set "PRIMARY=assets\vectors"
set "FALLBACK=..\assets\vectors"
set "OUTFILE=asset_paths.txt"
set "TARGET="

:: Use primary or fallback path
if exist "%PRIMARY%\" (
    set "TARGET=%PRIMARY%"
) else if exist "%FALLBACK%\" (
    echo Primary path not found. Using fallback path.
    set "TARGET=%FALLBACK%"
) else (
    echo Error: Neither "%PRIMARY%" nor "%FALLBACK%" exists.
    exit /b 1
)

:: Clear or create output file
> "%OUTFILE%" (
    for /d %%D in ("%TARGET%\*") do (
        set "dir=%%~nxD"
        if "%TARGET%"=="%PRIMARY%" (
            echo     - assets/vectors/!dir!/
        ) else (
            echo     - ../assets/vectors/!dir!/
        )
    )
)

echo Generated %OUTFILE%
endlocal
