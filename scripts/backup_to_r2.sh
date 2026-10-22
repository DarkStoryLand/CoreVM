#!/usr/bin/env bash
# DarkStory LAND - Database Backup Offsite Replication to Cloudflare R2
set -e

BACKUP_DIR="/opt/darkstory/backup/auto_backups"
R2_BUCKET="darkstory-patch-cdn"
R2_PATH="s3://${R2_BUCKET}/backups"

echo ">>> [$(date)] Starting Cloudflare R2 Offsite Backup Replication..."

if ! command -v aws > /dev/null 2>&1; then
    echo "    [INFO] AWS CLI not found. Installing lightweight AWS CLI for R2..."
    apt-get update && apt-get install -y awscli
fi

# Sync backup directory to Cloudflare R2 (keeps recent archives, deletes purged ones)
aws s3 sync "$BACKUP_DIR" "$R2_PATH"   --endpoint-url "https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"   --only-show-errors

echo ">>> [$(date)] R2 Offsite replication completed successfully."
