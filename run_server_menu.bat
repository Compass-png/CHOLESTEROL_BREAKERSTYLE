@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
pushd "%ROOT%"

set "PACKAGE_PROJECT=Content.Packaging\Content.Packaging.csproj"
set "SERVER_PROJECT=Content.Server"
set "WIN_RUNTIME=win-x64"
set "RELEASE_DIR=%ROOT%release"
set "PACKAGE_ZIP=%RELEASE_DIR%\SS14.Server_%WIN_RUNTIME%.zip"
set "HYBRID_LOG=%TEMP%\SectorHex_hybrid_build.log"
set "PACKAGING_BUILD_DIR=%ROOT%Content.Packaging\bin\Release\net10.0"
set "PACKAGING_STAGE_DIR=%TEMP%\SectorHexPackagingTool"

if /I "%~1"=="local" goto local
if /I "%~1"=="hybrid" goto hybrid
if /I "%~1"=="exit" goto end

:menu
cls
echo ==========================================
echo  Sector: Hex Server Launcher
echo ==========================================
echo.
echo  1. Local dev server
echo     Runs directly from source. No packaging.
echo.
echo  2. Full hybrid server package
echo     Builds a portable server package for another PC,
echo     without extracting or starting it.
echo.
echo  3. Exit
echo.
choice /c 123 /n /m "Select mode: "
if errorlevel 3 goto end
if errorlevel 2 goto hybrid
if errorlevel 1 goto local

:ensure_engine
if exist "%ROOT%RobustToolbox\Robust.Server\Robust.Server.csproj" goto :eof
echo.
echo RobustToolbox is missing. Running engine setup...
call "%ROOT%Scripts\bat\updateEngine.bat"
if errorlevel 1 exit /b 1
exit /b 0

:local
call :ensure_engine
if errorlevel 1 goto fail
echo.
echo Building Debug configuration...
dotnet build "%SERVER_PROJECT%" -c Debug
if errorlevel 1 goto fail
echo.
echo Starting local dev server...
dotnet run --project "%SERVER_PROJECT%" --no-build
if errorlevel 1 goto fail
goto done

:hybrid
call :ensure_engine
if errorlevel 1 goto fail

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"
if exist "%HYBRID_LOG%" del /f /q "%HYBRID_LOG%"

echo.
echo Preparing hybrid packaging tool...
dotnet build-server shutdown >nul 2>&1
dotnet build "%PACKAGE_PROJECT%" -c Release --nologo /m:1 > "%HYBRID_LOG%" 2>&1
if errorlevel 1 goto fail

if exist "%PACKAGING_STAGE_DIR%" rmdir /s /q "%PACKAGING_STAGE_DIR%"
mkdir "%PACKAGING_STAGE_DIR%" >> "%HYBRID_LOG%" 2>&1
robocopy "%PACKAGING_BUILD_DIR%" "%PACKAGING_STAGE_DIR%" /E /NFL /NDL /NJH /NJS /NC /NS /NP >> "%HYBRID_LOG%" 2>&1
if errorlevel 8 goto fail

echo.
echo Building hybrid portable server package...
set "MSBUILDDISABLENODEREUSE=1"
"%PACKAGING_STAGE_DIR%\Content.Packaging.exe" server --hybrid-acz --platform %WIN_RUNTIME% --configuration Release >> "%HYBRID_LOG%" 2>&1
if errorlevel 1 goto fail

if not exist "%PACKAGE_ZIP%" (
    echo.
    echo Package not found: "%PACKAGE_ZIP%"
    goto fail
)

echo.
echo Hybrid package built:
echo "%PACKAGE_ZIP%"
goto done

:fail
echo.
echo Operation failed.
if exist "%HYBRID_LOG%" echo Log: "%HYBRID_LOG%"
pause
goto end

:done
echo.
echo Done.
pause

:end
popd
endlocal
