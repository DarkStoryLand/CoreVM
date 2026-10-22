#!/usr/bin/env bash
# ==============================================================================
# DarkStory LAND (DSL) - Zero-Cost Offsite Backup Pull (Linux/Mac/WSL)
# ==============================================================================
set -euo pipefail

REMOTE_IP="168.222.2.57"
REMOTE_USER="root"
KEY_PATH="$HOME/.ssh/darkstory_root_ed25519"
LOCAL_BACKUP_DIR="/opt/darkstory/local_backups"
REMOTE_BACKUP_DIR="/opt/darkstory/backups"

mkdir -p "$LOCAL_BACKUP_DIR"

echo "[DSL BACKUP] Pulling archives from $REMOTE_IP..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_DIR/dsl_backup_*.tar.gz" "$LOCAL_BACKUP_DIR/"

# Retention: 30 days locally
find "$LOCAL_BACKUP_DIR" -type f -name "dsl_backup_*.tar.gz" -mtime +30 -delete
echo "[DSL BACKUP] Offsite backup pull completed successfully."
