@echo off
setlocal enabledelayedexpansion

REM Configure variables
set GITEA_URL=http://192.168.1.119:10009
set REPO_OWNER=MatiasDesu
set REPO_NAME=ThinkNote
set GITEA_TOKEN=47a4f2b9977498ab36e4e7e7ca77b7791c2df431
REM Replace with your Gitea token
set APK_PATH=%CD%/build/app/outputs/flutter-apk/app-release.apk
for /f "delims=" %%i in ('powershell.exe -Command "Get-Date -Format 'yyyyMMdd-HHmmss'"') do set RELEASE_TAG=v1.0.0-%%i
set RELEASE_NAME=Release %RELEASE_TAG%
set RELEASE_BODY=Automatic release from build script

REM Select build platform
echo Select the platforms for the build (comma-separated):
echo 1. Android (APK)
echo 2. Windows
echo 3. Linux
echo 4. Clean Gitea Releases
set /p PLATFORM_CHOICES="Choose options (1-4, e.g., 1,3): "

REM Replace commas with spaces for parsing
set PLATFORM_CHOICES=%PLATFORM_CHOICES:,= %

REM Validate choices
set ALL_VALID=1
for %%i in (%PLATFORM_CHOICES%) do (
    set IS_VALID=0
    if %%i==1 set IS_VALID=1
    if %%i==2 set IS_VALID=1
    if %%i==3 set IS_VALID=1
    if %%i==4 set IS_VALID=1
    if !IS_VALID!==0 (
        echo Invalid option: %%i
        set ALL_VALID=0
    )
)

if !ALL_VALID!==0 goto end

REM Process each choice in order
for %%i in (%PLATFORM_CHOICES%) do (
    if %%i==1 call :android_build
    if %%i==2 call :windows_build
    if %%i==3 call :linux_build
    if %%i==4 call :clean_releases
)
goto end

:android_build
REM Execute the build for Android
echo Building APK...
call flutter build apk --release

if %errorlevel% neq 0 (
    echo Build failed!
    exit /b 1
)

echo Build successful. APK created at %APK_PATH%

REM Create a release on Gitea
echo Creating release on Gitea...
curl --fail -X POST %GITEA_URL%/api/v1/repos/%REPO_OWNER%/%REPO_NAME%/releases?token=%GITEA_TOKEN% -H "Content-Type: application/json" -d "{\"tag_name\":\"%RELEASE_TAG%\",\"name\":\"%RELEASE_NAME%\",\"body\":\"%RELEASE_BODY%\"}" -o release_response.json
if %errorlevel% neq 0 (
    echo Failed to create release! Response:
    type release_response.json
    exit /b 1
)

REM Obtain the upload URL from the response
for /f "delims=" %%i in ('powershell.exe -Command "$release = Get-Content release_response.json | ConvertFrom-Json; $uploadUrl = $release.upload_url -replace '{.*}', ''; Write-Host $uploadUrl"') do set UPLOAD_URL=%%i

if "%UPLOAD_URL%"=="" (
    echo Failed to get upload URL! Response:
    type release_response.json
    exit /b 1
)

echo Release created. Upload URL: %UPLOAD_URL%

REM Upload the APK
echo Uploading APK...
curl --fail -s -X POST "%UPLOAD_URL%?name=app-release.apk&token=%GITEA_TOKEN%" -F "attachment=@%APK_PATH%" >nul

if %errorlevel% neq 0 (
    echo Failed to upload APK!
    exit /b 1
)

echo APK uploaded successfully.
goto :eof

:windows_build
REM Execute the build for Windows
echo Building Windows executable...
call flutter build windows

if %errorlevel% neq 0 (
    echo Build failed!
    exit /b 1
)

echo Build successful. Copying to destination...
set DEST_DIR="E:\Programas (descargados)\ThinkSoftware\ThinkNote"
if not exist %DEST_DIR% mkdir %DEST_DIR%
xcopy /E /I /Y "%CD%\build\windows\x64\runner\Release\*" %DEST_DIR%

if %errorlevel% neq 0 (
    echo Failed to copy files!
    exit /b 1
)

echo Files copied successfully to %DEST_DIR%
goto :eof

:linux_build
REM Execute the build for Linux
echo Building Linux executable...
call flutter build linux

if %errorlevel% neq 0 (
    echo Build failed!
    exit /b 1
)

echo Build successful.
echo To copy the files, run manually: xcopy /E /I /Y "%CD%\build\linux\x64\release\bundle\*" "YOUR_DESTINATION_FOLDER_HERE"
goto :eof

:clean_releases
REM Clean all releases on Gitea
echo Cleaning all releases on Gitea...
curl -X GET "%GITEA_URL%/api/v1/repos/%REPO_OWNER%/%REPO_NAME%/releases?token=%GITEA_TOKEN%" -o releases.json

if %errorlevel% neq 0 (
    echo Failed to fetch releases!
    exit /b 1
)

for /f "delims=" %%j in ('powershell.exe -Command "$releases = Get-Content releases.json | ConvertFrom-Json; foreach ($r in $releases) { Write-Host $r.id }"') do call :delete_release %%j

echo All releases cleaned.
goto :eof

:delete_release
set RELEASE_ID=%1
curl --fail -X DELETE "%GITEA_URL%/api/v1/repos/%REPO_OWNER%/%REPO_NAME%/releases/%RELEASE_ID%?token=%GITEA_TOKEN%"

if %errorlevel% neq 0 (
    echo Failed to delete release %RELEASE_ID%!
) else (
    echo Deleted release %RELEASE_ID%
)
goto :eof

:end
echo Script completed successfully!