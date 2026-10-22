@echo off
setlocal enabledelayedexpansion

:: ==============================================================================
:: DarkStory LAND (DSL) - Zero-Cost Automated Offsite Backup Pull Script
:: 100% Free & Self-Hosted: Direct SSH/SCP, No Cloud Storage, No Billing Needed
:: ==============================================================================

echo ==============================================================================
echo [DSL BACKUP] Starting DarkStory LAND Remote Backup Pull (Zero-Cost Sync)
echo ==============================================================================

set REMOTE_IP=168.222.2.57
set REMOTE_USER=root
set KEY_PATH=%USERPROFILE%\.ssh\darkstory_root_ed25519
set LOCAL_BACKUP_DIR=F:\DarkStory\Backups
set REMOTE_BACKUP_DIR=/opt/darkstory/backups

if not exist "%LOCAL_BACKUP_DIR%" (
    echo [DSL BACKUP] Creating local backup directory: %LOCAL_BACKUP_DIR%
    mkdir "%LOCAL_BACKUP_DIR%"
)

if not exist "%KEY_PATH%" (
    echo [ERROR] SSH private key not found at %KEY_PATH%
    exit /b 1
)

echo [DSL BACKUP] Pulling backup archives from remote server to local storage...
scp -i "%KEY_PATH%" -o StrictHostKeyChecking=no %REMOTE_USER%@%REMOTE_IP%:%REMOTE_BACKUP_DIR%/dsl_backup_*.tar.gz "%LOCAL_BACKUP_DIR%"

if %ERRORLEVEL% equ 0 (
    echo [DSL BACKUP] Backup sync completed successfully!
    echo [DSL BACKUP] Files stored in: %LOCAL_BACKUP_DIR%
) else (
    echo [ERROR] Backup pull encountered an error (Code: %ERRORLEVEL%)
)

:: Retention: Delete local backups older than 30 days
forfiles /P "%LOCAL_BACKUP_DIR%" /M dsl_backup_*.tar.gz /D -30 /C "cmd /c del @path" 2>nul

echo ==============================================================================
echo [DSL BACKUP] Finished.
echo ==============================================================================
