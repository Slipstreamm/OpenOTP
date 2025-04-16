@echo off
setlocal

:: First path to try
set PRIMARY_SCRIPT=./generate_asset_paths.sh
:: Fallback if the first one is missing
set FALLBACK_SCRIPT=./utils/generate_asset_paths.sh

:: Check for WSL
where wsl >nul 2>&1
if errorlevel 1 (
    echo Error: WSL not found on this system.
    exit /b 1
)

:: Try running the primary script
echo Trying: %PRIMARY_SCRIPT%
wsl -e bash -c "if [ -f '%PRIMARY_SCRIPT%' ]; then bash '%PRIMARY_SCRIPT%'; elif [ -f '%FALLBACK_SCRIPT%' ]; then echo 'Primary script not found. Using fallback.'; bash '%FALLBACK_SCRIPT%'; else echo 'Error: Neither script found.'; exit 1; fi"

endlocal