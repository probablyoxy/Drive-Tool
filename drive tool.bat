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

:: Use PowerShell to map volumes directly to ensure optical drives are included
for /f "tokens=*" %%D in ('powershell -NoProfile -Command "Get-Volume | Where-Object DriveLetter | Sort-Object Size -Descending | ForEach-Object { $disk = Get-Partition -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue; $model = if ($disk) { $disk.Model } else { $_.DriveType }; $size = if ($_.Size) { '{0} GB' -f [math]::Round($_.Size/1GB, 2) } else { '0 GB' }; '{0,-6} {1,-13} {2,-20} {3}' -f ($_.DriveLetter + ':'), $size, $_.FileSystemLabel, $model }"') do (
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

:: Use PowerShell to map physical volumes, appended with mapped network drives from the user's registry
for /f "tokens=*" %%D in ('powershell -NoProfile -Command "Get-Volume | Where-Object DriveLetter | Sort-Object Size -Descending | ForEach-Object { $disk = Get-Partition -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue; $model = if ($disk) { $disk.Model } else { $_.DriveType }; $size = if ($_.Size) { '{0} GB' -f [math]::Round($_.Size/1GB, 2) } else { '0 GB' }; '{0,-6} {1,-13} {2,-20} {3}' -f ($_.DriveLetter + ':'), $size, $_.FileSystemLabel, $model }; Get-ChildItem -Path HKCU:\Network -ErrorAction SilentlyContinue | ForEach-Object { $letter = $_.PSChildName + ':'; $remote = $_.GetValue('RemotePath'); '{0,-6} {1,-13} {2,-20} {3}' -f $letter, 'Network', 'Mapped Drive', $remote }"') do (
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

:: Network drive translation
set "SourcePath=!SourceDrive!:"
set "SourceIsNetwork=0"
for /f "tokens=2*" %%B in ('reg query "HKCU\Network\!SourceDrive!" /v RemotePath 2^>nul ^| find "RemotePath"') do (
    set "SourcePath=%%C"
    set "SourceIsNetwork=1"
)

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

:: Use PowerShell to map physical volumes, appended with mapped network drives from the user's registry
for /f "tokens=*" %%D in ('powershell -NoProfile -Command "Get-Volume | Where-Object DriveLetter | Sort-Object Size -Descending | ForEach-Object { $disk = Get-Partition -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue; $model = if ($disk) { $disk.Model } else { $_.DriveType }; $size = if ($_.Size) { '{0} GB' -f [math]::Round($_.Size/1GB, 2) } else { '0 GB' }; '{0,-6} {1,-13} {2,-20} {3}' -f ($_.DriveLetter + ':'), $size, $_.FileSystemLabel, $model }; Get-ChildItem -Path HKCU:\Network -ErrorAction SilentlyContinue | ForEach-Object { $letter = $_.PSChildName + ':'; $remote = $_.GetValue('RemotePath'); '{0,-6} {1,-13} {2,-20} {3}' -f $letter, 'Network', 'Mapped Drive', $remote }"') do (
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

:: Network drive translation
set "DestPath=!DestDrive!:"
set "DestIsNetwork=0"
for /f "tokens=2*" %%B in ('reg query "HKCU\Network\!DestDrive!" /v RemotePath 2^>nul ^| find "RemotePath"') do (
    set "DestPath=%%C"
    set "DestIsNetwork=1"
)

echo.
echo Calculating sizes and checking available free space. Please wait...

if "%CopyChoice%"=="1" goto CheckDriveSize
if "%CopyChoice%"=="2" goto CheckUsersSize

:CheckDriveSize
powershell -NoProfile -Command "$ErrorActionPreference = 'SilentlyContinue'; $fso = New-Object -ComObject Scripting.FileSystemObject; $dest = $fso.GetDrive('!DestPath!'); $src = $fso.GetDrive('!SourcePath!'); $srcUsed = $src.TotalSize - $src.FreeSpace; if ($dest.FreeSpace -gt $srcUsed) { exit 0 } else { exit 1 }"
if %errorlevel% neq 0 goto SpaceError
goto SizeCheckPassed

:CheckUsersSize
robocopy "!SourcePath!\Users" "!DestPath!\Dummy" /L /E /XJ /BYTES /NJH /NDL /NFL /NP /UNILOG:"%TEMP%\robo_size.log" >nul 2>&1

powershell -NoProfile -Command "$ErrorActionPreference = 'SilentlyContinue'; $logPath = $env:TEMP + '\robo_size.log'; $log = Get-Content -LiteralPath $logPath -Encoding Unicode; $bytesLine = $log | Where-Object { $_ -match 'Bytes\s*:\s+(\d+)' } | Select-Object -First 1; if ($bytesLine -match 'Bytes\s*:\s+(\d+)') { $srcBytes = [long]$matches[1]; $fso = New-Object -ComObject Scripting.FileSystemObject; $dest = $fso.GetDrive('!DestPath!'); if ($dest.FreeSpace -gt $srcBytes) { exit 0 } else { exit 1 } } else { exit 0 }"
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

if "!DestIsNetwork!"=="1" ( (
    echo.
    echo ------------------------------------------------------------------------
    echo Network Data Transfer from "!SourceDrive!:" to "!DestDrive!:" Started at !TIME! on !DATE! ) >> "%USERPROFILE%\Desktop\Data Transfer.txt"
 goto NetworkStagedTransfer
)

:LocalDirectTransfer
set "StartTime=!DATE! !TIME!"
if "%CopyChoice%"=="1" ( (
    echo.
    echo ------------------------------------------------------------------------
    echo Data Transfer from "!SourceDrive!:" to "!DestDrive!:" Started at !TIME! on !DATE! ) >> "%USERPROFILE%\Desktop\Data Transfer.txt"
    robocopy "!SourcePath!\" "!DestPath!\" /E /R:3 /W:0 /XJ /B /COPY:DAT /XD "$RECYCLE.BIN" "System Volume Information" "Config.Msi" /LOG:"%TEMP%\robocopy_last.log" /TEE
)
if "%CopyChoice%"=="2" ( (
    echo.
    echo -------------------------------------------------------------------------
    echo Users Transfer from "!SourceDrive!:" to "!DestDrive!:" Started at !TIME! on !DATE! )  >> "%USERPROFILE%\Desktop\Data Transfer.txt"
    robocopy "!SourcePath!\Users" "!DestPath!\Users" /E /R:3 /W:0 /XJ /B /COPY:DAT /LOG:"%TEMP%\robocopy_last.log" /TEE
)
set "EndTime=!DATE! !TIME!"
goto WriteLog

:NetworkStagedTransfer
set "StartTime=!DATE! !TIME!"
set "PsScript=%TEMP%\stage_transfer.ps1"

:: Dynamically generate PowerShell file-by-file staging logic
echo $ErrorActionPreference = 'SilentlyContinue' > "!PsScript!"
echo $srcBase = '!SourcePath!' >> "!PsScript!"
echo $dstBase = '!DestPath!' >> "!PsScript!"
echo $choice = '%CopyChoice%' >> "!PsScript!"
echo if ($choice -eq '1') { $src = $srcBase; $dest = $dstBase } else { $src = Join-Path $srcBase 'Users'; $dest = Join-Path $dstBase 'Users' } >> "!PsScript!"
echo $tempBase = Join-Path $env:TEMP 'RoboStage' >> "!PsScript!"
echo if (Test-Path $tempBase) { Remove-Item $tempBase -Recurse -Force ^| Out-Null } >> "!PsScript!"
echo New-Item -ItemType Directory -Path $tempBase ^| Out-Null >> "!PsScript!"
echo Write-Host 'Scanning for locked files using Backup Mode... Please wait.' -ForegroundColor Cyan >> "!PsScript!"
echo $listArgs = @($src, 'C:\dummy', '/E', '/B', '/L', '/XJ', '/FP', '/NJH', '/NJS', '/NDL', '/NC', '/NS') >> "!PsScript!"
echo if ($choice -eq '1') { $listArgs += @('/XD', "`$RECYCLE.BIN", 'System Volume Information', 'Config.Msi') } >> "!PsScript!"
echo $fileLines = ^& robocopy $listArgs >> "!PsScript!"
echo $validFiles = @() >> "!PsScript!"
echo foreach ($line in $fileLines) { >> "!PsScript!"
echo     $path = $line.Trim() >> "!PsScript!"
echo     if ($path.Length -gt 2) { $validFiles += $path } >> "!PsScript!"
echo } >> "!PsScript!"
echo $total = $validFiles.Count >> "!PsScript!"
echo $i = 0 >> "!PsScript!"
echo $escSrc = [regex]::Escape($src) >> "!PsScript!"
echo foreach ($path in $validFiles) { >> "!PsScript!"
echo     $i++ >> "!PsScript!"
echo     $fileName = Split-Path $path -Leaf >> "!PsScript!"
echo     $srcParent = Split-Path $path -Parent >> "!PsScript!"
echo     $rel = ($path -ireplace "^$escSrc", '').TrimStart('\') >> "!PsScript!"
echo     $tmp = Join-Path $tempBase $rel >> "!PsScript!"
echo     $dst = Join-Path $dest $rel >> "!PsScript!"
echo     $tmpDir = Split-Path $tmp -Parent >> "!PsScript!"
echo     $dstDir = Split-Path $dst -Parent >> "!PsScript!"
echo     if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force ^| Out-Null } >> "!PsScript!"
echo     if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force ^| Out-Null } >> "!PsScript!"
echo     Write-Progress -Activity 'File Staging Transfer to NAS' -Status "[$i / $total] $fileName" -PercentComplete (($i / $total) * 100) >> "!PsScript!"
echo     $robocopyArgs1 = @($srcParent, $tmpDir, $fileName, '/R:3', '/W:0', '/B', '/COPY:DAT', '/XJ', '/NJH', '/NJS', '/NDL', '/NC', '/NS', '/NP') >> "!PsScript!"
echo     ^& robocopy $robocopyArgs1 ^| Out-Null >> "!PsScript!"
echo     $robocopyArgs2 = @($tmpDir, $dstDir, $fileName, '/R:3', '/W:0', '/COPY:DAT', '/XJ', '/NJH', '/NJS', '/NDL', '/NC', '/NS', '/NP') >> "!PsScript!"
echo     ^& robocopy $robocopyArgs2 ^| Out-Null >> "!PsScript!"
echo     Remove-Item $tmp -Force >> "!PsScript!"
echo } >> "!PsScript!"
echo Write-Progress -Activity 'File Staging Transfer to NAS' -Completed >> "!PsScript!"
echo Remove-Item $tempBase -Recurse -Force ^| Out-Null >> "!PsScript!"

powershell -NoProfile -ExecutionPolicy Bypass -File "!PsScript!"
del "!PsScript!"
set "EndTime=!DATE! !TIME!"

:: Fake a robocopy log for the network output to keep log parsing happy
(
    echo Copied Files to Network Location
    echo.
) > "%TEMP%\robocopy_last.log"

goto WriteLog

:WriteLog
for /f "delims=" %%T in ('powershell -NoProfile -Command "$ts = [datetime]'!EndTime!' - [datetime]'!StartTime!'; '{0:00}h {1:00}m {2:00}s' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds"') do (
    set "Duration=%%T")

echo.
echo Transfer complete.
if "%CopyChoice%"=="1" ( (
    echo Data Transfer from "!SourceDrive!:" to "!DestDrive!:" Completed at %TIME% on %DATE%
    echo Transfer Duration: !Duration!
    echo.
    powershell -NoProfile -Command "$log = Get-Content '%TEMP%\robocopy_last.log'; $idx = ($log | Select-String '^\s+Total\s+Copied').LineNumber; if ($idx) { $log[($idx-1)..($log.Count-2)] }"
    echo ------------------------------------------------------------------------
    echo.
    ) >> "%USERPROFILE%\Desktop\Data Transfer.txt")
if "%CopyChoice%"=="2" ( (
    echo Users Transfer from "!SourceDrive!:" to "!DestDrive!:" Completed at %TIME% on %DATE% 
    echo Transfer Duration: !Duration!
    echo.
    echo Copied Users:
    for /d %%U in ("!DestPath!\Users\*") do ( echo %%~nxU^ )
    echo.
    powershell -NoProfile -Command "$log = Get-Content '%TEMP%\robocopy_last.log'; $idx = ($log | Select-String '^\s+Total\s+Copied').LineNumber; if ($idx) { $log[($idx-1)..($log.Count-2)] }"
    echo -------------------------------------------------------------------------
    echo.
    ) >> "%USERPROFILE%\Desktop\Data Transfer.txt")
pause
goto MainMenu