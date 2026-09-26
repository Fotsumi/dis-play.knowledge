@echo off
REM DIS-PLAY Installer Build Script
REM Builds the release binary, then packages it with NSIS (makensis).

setlocal enabledelayedexpansion

echo ========================================
echo DIS-PLAY Installer Build
echo ========================================
echo.

REM The NSIS compiler is makensis.exe (NSIS.exe is the editor/IDE).
where makensis >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: makensis not found in PATH
    echo Please add the NSIS bin directory (e.g. C:\Program Files ^(x86^)\NSIS) to PATH.
    pause
    exit /b 1
)

echo [1/3] Building release binary...
pushd product
cargo build --release
if %ERRORLEVEL% neq 0 (
    echo ERROR: cargo build failed
    popd
    pause
    exit /b 1
)
popd

echo.
echo [2/3] Verifying build artifact...
if not exist "product\target\release\dis-play.exe" (
    echo ERROR: dis-play.exe not found in product\target\release
    pause
    exit /b 1
)

echo.
echo [3/3] Building NSIS installer...
makensis installer.nsi
if %ERRORLEVEL% neq 0 (
    echo ERROR: NSIS build failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build Complete!
echo Installer: dis-play-setup.exe
echo ========================================
echo.
pause