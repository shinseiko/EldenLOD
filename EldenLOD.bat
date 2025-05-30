@echo off
setlocal EnableDelayedExpansion

REM ========================================================================
REM EldenLOD - Unified Command Interface for EldenLOD Tools
REM Version: 0.1-alpha
REM Author: shinseiko
REM Date: 2025-05-30
REM ========================================================================

REM Set script paths
set "SCRIPT_DIR=%~dp0scripts"
set "DOCS_DIR=%~dp0docs\help"
set "EXTRACT_SCRIPT=%SCRIPT_DIR%\EldenLOD-Extract.ps1"
set "REPACK_SCRIPT=%SCRIPT_DIR%\EldenLOD-Repack.ps1"
set "INVOKE_SCRIPT=%SCRIPT_DIR%\Invoke-EldenLOD.ps1"
set "MODULE_FILE=%SCRIPT_DIR%\EldenLOD.psm1"
set "HELP_FILE=%DOCS_DIR%\USAGE.md"
set "TEST_SCRIPT=%~dp0tests\Test-EldenLOD.ps1"

REM Initialize
set "COMMAND="
set "COMMAND_OPTIONS="
set "SHOW_HELP=0"
set "ERROR_LEVEL=0"

REM Parse Command
if "%~1"=="" (
    set "SHOW_HELP=1"
) else (
    set "COMMAND=%~1"
    shift
)

REM Parse Options (shift removes the command and keeps only the options)
:ParseOptions
if "%~1"=="" goto :EndOfOptions
set "COMMAND_OPTIONS=%COMMAND_OPTIONS% %~1"
shift
goto :ParseOptions
:EndOfOptions

REM Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: PowerShell is not available. Please install PowerShell to use EldenLOD.
    exit /b 1
)

REM Process commands
if /i "%COMMAND%"=="help" (
    set "SHOW_HELP=1"
) else if /i "%COMMAND%"=="extract" (
    call :RunExtract %COMMAND_OPTIONS%
) else if /i "%COMMAND%"=="repack" (
    call :RunRepack %COMMAND_OPTIONS%
) else if /i "%COMMAND%"=="full" (
    call :RunFull %COMMAND_OPTIONS%
) else if /i "%COMMAND%"=="invoke" (
    call :RunInvoke %COMMAND_OPTIONS%
) else if /i "%COMMAND%"=="test" (
    call :RunTest %COMMAND_OPTIONS%
) else (
    echo Unknown command: %COMMAND%
    set "SHOW_HELP=1"
    set "ERROR_LEVEL=1"
)

REM Show help if needed
if %SHOW_HELP% equ 1 (
    call :ShowHelp %COMMAND%
)

exit /b %ERROR_LEVEL%

REM ========================================================================
REM Functions
REM ========================================================================

:CheckScriptExists
REM Check if a script exists
if not exist "%~1" (
    echo Error: Script not found: %~1
    echo Please ensure all EldenLOD files are properly installed.
    set "ERROR_LEVEL=1"
    exit /b 1
)
exit /b 0

:RunExtract
REM Run extraction script
call :CheckScriptExists "%EXTRACT_SCRIPT%"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Running EldenLOD Extract...
powershell -ExecutionPolicy Bypass -File "%EXTRACT_SCRIPT%" %*
set "ERROR_LEVEL=%ERRORLEVEL%"
if %ERROR_LEVEL% neq 0 (
    echo Error: Extract operation failed with code %ERROR_LEVEL%.
    echo Please check the log files in the _logs directory for details.
) else (
    echo Extract operation completed successfully.
)
exit /b %ERROR_LEVEL%

:RunRepack
REM Run repack script
call :CheckScriptExists "%REPACK_SCRIPT%"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Running EldenLOD Repack...
powershell -ExecutionPolicy Bypass -File "%REPACK_SCRIPT%" %*
set "ERROR_LEVEL=%ERRORLEVEL%"
if %ERROR_LEVEL% neq 0 (
    echo Error: Repack operation failed with code %ERROR_LEVEL%.
    echo Please check the log files in the _logs directory for details.
) else (
    echo Repack operation completed successfully.
)
exit /b %ERROR_LEVEL%

:RunFull
REM Run both extract and repack
call :CheckScriptExists "%EXTRACT_SCRIPT%"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
call :CheckScriptExists "%REPACK_SCRIPT%"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Running EldenLOD Full Process (Extract + Repack)...
powershell -ExecutionPolicy Bypass -File "%EXTRACT_SCRIPT%" %*
set "ERROR_LEVEL=%ERRORLEVEL%"
if %ERROR_LEVEL% neq 0 (
    echo Error: Extract operation failed with code %ERROR_LEVEL%.
    echo Full process aborted.
    echo Please check the log files in the _logs directory for details.
    exit /b %ERROR_LEVEL%
)

powershell -ExecutionPolicy Bypass -File "%REPACK_SCRIPT%" %*
set "ERROR_LEVEL=%ERRORLEVEL%"
if %ERROR_LEVEL% neq 0 (
    echo Error: Repack operation failed with code %ERROR_LEVEL%.
    echo Please check the log files in the _logs directory for details.
) else (
    echo Full process completed successfully.
)
exit /b %ERROR_LEVEL%

:RunInvoke
REM Run invoke script with custom operation
call :CheckScriptExists "%INVOKE_SCRIPT%"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Running EldenLOD Invoke...
powershell -ExecutionPolicy Bypass -File "%INVOKE_SCRIPT%" %*
set "ERROR_LEVEL=%ERRORLEVEL%"
if %ERROR_LEVEL% neq 0 (
    echo Error: Invoke operation failed with code %ERROR_LEVEL%.
    echo Please check the log files in the _logs directory for details.
) else (
    echo Invoke operation completed successfully.
)
exit /b %ERROR_LEVEL%

:RunTest
REM Run test script
call :CheckScriptExists "%TEST_SCRIPT%"
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo Running EldenLOD Tests...
powershell -ExecutionPolicy Bypass -File "%TEST_SCRIPT%" %*
set "ERROR_LEVEL=%ERRORLEVEL%"
if %ERROR_LEVEL% neq 0 (
    echo Error: Tests failed with code %ERROR_LEVEL%.
    echo Please check the test results for details.
) else (
    echo Tests completed successfully.
)
exit /b %ERROR_LEVEL%

:ShowHelp
REM Display help based on the docs/help/USAGE.md file
if exist "%HELP_FILE%" (
    REM If a specific command is requested, try to extract that section
    if not "%~1"=="" (
        echo EldenLOD Help: %~1
        echo =====================
        powershell -Command "& { $content = Get-Content -Raw '%HELP_FILE%'; $pattern = '(?s)### Command: %~1.*?(?=### Command:|## Operations|$)'; if ($content -match $pattern) { $matches[0] } else { Write-Host 'No help found for command: %~1' }}"
    ) else (
        echo EldenLOD Help
        echo ============
        powershell -Command "& { $content = Get-Content -Raw '%HELP_FILE%'; $pattern = '(?s)## Commands.*?(?=## Operations|$)'; if ($content -match $pattern) { $matches[0] } else { Write-Host 'Help content not found.' }}"
    )
) else (
    echo EldenLOD Help
    echo ============
    echo Basic usage: EldenLOD ^<command^> [options]
    echo.
    echo Commands:
    echo   extract - Extract LOD files
    echo   repack  - Repack LOD files
    echo   full    - Perform extract and repack in sequence
    echo   invoke  - Invoke a specific operation
    echo   test    - Run tests
    echo   help    - Show this help
    echo.
    echo For more information, see README.md
)
exit /b 0
