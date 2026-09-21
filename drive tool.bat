@echo off
setlocal EnableDelayedExpansion

:: check for administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please right-click the script and select "Run as administrator".
    echo.
    pause
    exit /b 1
)



:: ========================================
:: MAIN MENU
:: ========================================
:MainMenu
cls
echo ========================================
echo               DRIVE TOOLS
echo ========================================
echo 1. takeown
echo 2. Data Transfer
echo 0. Exit
echo ========================================
echo.
set "MenuChoice="
set /p "MenuChoice=Select an option: "

if "%MenuChoice%"=="1" goto OptTakeOwn
if "%MenuChoice%"=="2" goto OptDataTransfer
if "%MenuChoice%"=="0" exit /b

echo Invalid selection. Please try again.
timeout /t 2 >nul
goto MainMenu



:: ========================================
:: OPTION 1: takeown & icacls
:: ========================================
:OptTakeOwn
cls
echo ========================================
echo              TAKE OWNERSHIP             
echo ========================================
echo Scanning drives...
echo.
echo Drive  Size          Name                 Hardware
echo ----------------------------------------------------------------

:: Use PowerShell to map partitions to physical disks and format the output
for /f "tokens=*" %%D in ('powershell -NoProfile -Command "Get-Partition | Where-Object DriveLetter | Sort-Object Size -Descending | ForEach-Object { $disk = Get-Disk -Number $_.DiskNumber; $vol = Get-Volume -DriveLetter $_.DriveLetter; '{0,-6} {1,-13} {2,-20} {3}' -f ($_.DriveLetter + ':'), ('{0} GB' -f [math]::Round($vol.Size/1GB, 2)), $vol.FileSystemLabel, $disk.Model }"') do (
    echo %%D
)

echo ----------------------------------------------------------------
echo type "0" to exit
echo.
set "DriveLetter="
set /p "DriveLetter=Enter drive letter: "

:: drive validation
if "!DriveLetter!"=="" (
    echo No drive selected.
    timeout /t 2 >nul
    goto OptTakeOwn
)

if "!DriveLetter!"=="0" goto MainMenu

:: cleanup (removes the colon, i.e. "D:")
set "DriveLetter=!DriveLetter::=!"

:: warning for the system drive
if /I "!DriveLetter!"=="C" (
    echo.
    echo WARNING: Taking ownership and granting Everyone full control on the C:\ drive root
    echo will overwrite default Windows security descriptors. This can break Windows Apps,
    echo cause boot failures, and severely compromise system security.
    set /p "ConfirmC=Are you absolutely sure you want to proceed with C:? (Y/N): "
    if /I not "!ConfirmC!"=="Y" (
        echo Aborting operation...
        timeout /t 2 >nul
        goto MainMenu
    )
)

echo ========================================
echo          Select takeown Action           
echo ========================================
echo 1. Entire Drive
echo 2. Users Folder
echo 0. Exit
echo ----------------------------------------
set "TakeOwnType="
set /p "TakeOwnType=Select Option: "

if "%TakeOwnType%"=="0" goto MainMenu
if "%TakeOwnType%"=="1" goto TakeOwnAll
if "%TakeOwnType%"=="2" goto TakeOwnUsers

echo Invalid selection. Please try again.
timeout /t 2 >nul
goto OptTakeOwn

:TakeOwnAll
echo.
echo Beginning operations on !DriveLetter!:\...
echo.

echo [1/2] Running takeown...
takeown /f "!DriveLetter!:\*" /r /d y

echo.
echo [2/2] Running icacls...
icacls "!DriveLetter!:\*" /grant Everyone:F /t /c /q

echo.
echo Operation complete.
pause
goto MainMenu

:TakeOwnUsers
echo.
echo Beginning operations on !DriveLetter!:\...
echo.

echo [1/2] Running takeown...
takeown /f "!DriveLetter!:\Users" /r /d y

echo.
echo [2/2] Running icacls...
icacls "!DriveLetter!:\Users" /grant Everyone:F /t /c /q

echo.
echo Operation complete.
pause
goto MainMenu



:: ========================================
:: OPTION 2: Data Transfer
:: ========================================
:OptDataTransfer
cls
echo ========================================
echo             DATA TRANSFER
echo ========================================
echo Scanning drives for SOURCE selection...
echo.
echo Drive  Size          Name                 Hardware
echo ----------------------------------------------------------------

:: Use PowerShell to map partitions to physical disks and format the output
for /f "tokens=*" %%D in ('powershell -NoProfile -Command "Get-Partition | Where-Object DriveLetter | Sort-Object Size -Descending | ForEach-Object { $disk = Get-Disk -Number $_.DiskNumber; $vol = Get-Volume -DriveLetter $_.DriveLetter; '{0,-6} {1,-13} {2,-20} {3}' -f ($_.DriveLetter + ':'), ('{0} GB' -f [math]::Round($vol.Size/1GB, 2)), $vol.FileSystemLabel, $disk.Model }"') do (
    echo %%D
)

echo ----------------------------------------------------------------
echo type "0" to exit
echo.
set "SourceDrive="
set /p "SourceDrive=Enter SOURCE drive letter: "

if "!SourceDrive!"=="" goto OptDataTransfer
if "!SourceDrive!"=="0" goto MainMenu
set "SourceDrive=!SourceDrive::=!"

echo.
echo ========================================
echo          Select Data to Copy
echo ========================================
echo 1. Entire Drive
echo 2. Users Folder
echo 0. Exit
echo ----------------------------------------
set "CopyChoice="
set /p "CopyChoice=Select Option: "

if "%CopyChoice%"=="0" goto MainMenu
if not "%CopyChoice%"=="1" if not "%CopyChoice%"=="2" (
    echo Invalid selection. Please try again.
    timeout /t 2 >nul
    goto OptDataTransfer
)

:DestPrompt
echo.
echo ========================================
echo             DATA TRANSFER
echo ========================================
echo Scanning drives for DESTINATION selection...
echo.
echo Drive  Size          Name                 Hardware
echo ----------------------------------------------------------------

:: Use PowerShell to map partitions to physical disks and format the output
for /f "tokens=*" %%D in ('powershell -NoProfile -Command "Get-Partition | Where-Object DriveLetter | Sort-Object Size -Descending | ForEach-Object { $disk = Get-Disk -Number $_.DiskNumber; $vol = Get-Volume -DriveLetter $_.DriveLetter; '{0,-6} {1,-13} {2,-20} {3}' -f ($_.DriveLetter + ':'), ('{0} GB' -f [math]::Round($vol.Size/1GB, 2)), $vol.FileSystemLabel, $disk.Model }"') do (
    echo %%D
)

echo ----------------------------------------------------------------
echo type "0" to exit
echo.
set "DestDrive="
set /p "DestDrive=Enter DESTINATION drive letter: "

if "!DestDrive!"=="" goto DestPrompt
if "!DestDrive!"=="0" goto MainMenu
set "DestDrive=!DestDrive::=!"

if /I "!SourceDrive!"=="!DestDrive!" (
    echo.
    echo ERROR: Source and Destination cannot be the same drive.
    timeout /t 2 >nul
    goto DestPrompt
)

echo.
echo Calculating sizes and checking available free space. Please wait...

if "%CopyChoice%"=="1" goto CheckDriveSize
if "%CopyChoice%"=="2" goto CheckUsersSize

:CheckDriveSize
powershell -NoProfile -Command "$ErrorActionPreference = 'SilentlyContinue'; $dest = Get-Volume -DriveLetter '!DestDrive!'; $src = Get-Volume -DriveLetter '!SourceDrive!'; if ($dest.SizeRemaining -gt ($src.Size - $src.SizeRemaining)) { exit 0 } else { exit 1 }"
if %errorlevel% neq 0 goto SpaceError
goto SizeCheckPassed

:CheckUsersSize
robocopy "!SourceDrive!:\Users" "!DestDrive!:\Dummy" /L /E /XJ /BYTES /NJH /NDL /NFL /NP /UNILOG:"%TEMP%\robo_size.log" >nul 2>&1

:: Read the log to get the byte count and compare it to destination free space
powershell -NoProfile -Command "$ErrorActionPreference = 'SilentlyContinue'; $logPath = $env:TEMP + '\robo_size.log'; $log = Get-Content -LiteralPath $logPath -Encoding Unicode; $bytesLine = $log | Where-Object { $_ -match 'Bytes\s*:\s+(\d+)' } | Select-Object -First 1; if ($bytesLine -match 'Bytes\s*:\s+(\d+)') { $srcBytes = [long]$matches[1]; $dest = Get-Volume -DriveLetter '!DestDrive!'; if ($dest.SizeRemaining -gt $srcBytes) { exit 0 } else { exit 1 } } else { exit 0 }"
if %errorlevel% neq 0 goto SpaceError
goto SizeCheckPassed

:SpaceError
echo.
echo ERROR: Not enough free space on Destination Drive (!DestDrive!:).
echo The source files are larger than the available space. Transfer aborted.
echo.
pause
goto OptDataTransfer

:SizeCheckPassed
echo.
echo Size check passed. Starting transfer...
echo.

if "%CopyChoice%"=="1" (
    robocopy "!SourceDrive!:\" "!DestDrive!:\" /E /R:1 /W:1 /XJ /B /COPY:DAT /XD "$RECYCLE.BIN" "System Volume Information" "Config.Msi"
)
if "%CopyChoice%"=="2" (
    robocopy "!SourceDrive!:\Users" "!DestDrive!:\Users" /E /R:1 /W:1 /XJ /B /COPY:DAT
)

echo.
echo Transfer complete.
pause
goto MainMenu