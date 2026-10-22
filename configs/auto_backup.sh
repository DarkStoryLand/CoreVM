#!/usr/bin/env bash
# ==============================================================================
# DarkStory LAND (DSL) - Automated Database Backup & Retention Manager
# 100% Zero-Cost / Self-Hosted: No Cloudflare R2, No AWS S3, No Billing Needed.
#
# Backs up:
#   1. MSSQL: MHCMember, MHGame, MHLog
#   2. SQLite Web DB: darkstory_web.db
# Retention: 7 Days (older backups automatically pruned)
# Runs every 6 hours via crontab: 0 */6 * * * /opt/darkstory/docker/auto_backup.sh
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_BACKUP_DIR="${BACKUP_DIR:-/opt/darkstory/backups}"
CONTAINER_BACKUP_DIR="/var/opt/mssql/auto_backups"
DB_CONTAINER="darkstory_mssql"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEMP_BUNDLE_DIR="/tmp/dsl_backup_${TIMESTAMP}"

if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/.env"
    set +a
fi
: "${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD must be set in docker/.env}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"

mkdir -p "$HOST_BACKUP_DIR"
mkdir -p "$TEMP_BUNDLE_DIR"

# Ensure container backup directory exists and has correct permissions for mssql user
docker exec -u 0 "$DB_CONTAINER" mkdir -p "$CONTAINER_BACKUP_DIR" 2>/dev/null || true
docker exec -u 0 "$DB_CONTAINER" chown -R mssql:0 "$CONTAINER_BACKUP_DIR" 2>/dev/null || true

# Find sqlcmd inside mssql container
SQLCMD=$(docker exec "$DB_CONTAINER" sh -c 'ls /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd 2>/dev/null | head -1')
if [ -z "$SQLCMD" ]; then
    echo "!!! ERROR: sqlcmd not found in $DB_CONTAINER"
    exit 1
fi
SQLCMD_OPTS=""
case "$SQLCMD" in *tools18*) SQLCMD_OPTS="-C" ;; esac

echo ">>> [$(date)] Starting DSL Zero-Cost Automated Backup Routine..."

databases=("MHCMember" "MHGame" "MHLog")
failed_dbs=()

for db in "${databases[@]}"; do
    filename="${db}_backup_${TIMESTAMP}.bak"
    echo ">>> Backing up MSSQL Database: $db -> $filename"

    if docker exec -e SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" "$DB_CONTAINER" "$SQLCMD" $SQLCMD_OPTS \
        -S localhost -U sa -b \
        -Q "BACKUP DATABASE [$db] TO DISK = N'$CONTAINER_BACKUP_DIR/$filename' WITH COMPRESSION, CHECKSUM, STATS = 25;" \
        && docker cp "$DB_CONTAINER:$CONTAINER_BACKUP_DIR/$filename" "$TEMP_BUNDLE_DIR/$filename"; then

        docker exec "$DB_CONTAINER" rm -f "$CONTAINER_BACKUP_DIR/$filename"
        gzip -9 "$TEMP_BUNDLE_DIR/$filename"
        echo ">>> Successfully backed up: $db"
    else
        echo "!!! ERROR: Failed to backup $db"
        failed_dbs+=("$db")
    fi
done

# Backup SQLite Web Database
WEB_DB="/opt/darkstory/web/server/darkstory_web.db"
if [ -f "$WEB_DB" ]; then
    echo ">>> Backing up SQLite Web Database: darkstory_web.db"
    sqlite_bak="${TEMP_BUNDLE_DIR}/darkstory_web_${TIMESTAMP}.db"
    sqlite3 "$WEB_DB" ".backup '$sqlite_bak'" || cp "$WEB_DB" "$sqlite_bak"
    gzip -9 "$sqlite_bak"
    echo ">>> Successfully backed up: SQLite Web DB"
fi

# Create single unified tar.gz archive
BUNDLE_ARCHIVE="${HOST_BACKUP_DIR}/dsl_backup_${TIMESTAMP}.tar.gz"
tar -czf "$BUNDLE_ARCHIVE" -C "$TEMP_BUNDLE_DIR" .
rm -rf "$TEMP_BUNDLE_DIR"
echo ">>> Consolidated backup archive created: $BUNDLE_ARCHIVE ($(du -h "$BUNDLE_ARCHIVE" | cut -f1))"

# Prune backups older than 7 days
echo ">>> Pruning archives older than 7 days in $HOST_BACKUP_DIR..."
find "$HOST_BACKUP_DIR" -type f -name "dsl_backup_*.tar.gz" -mtime +7 -delete

# Discord Notification (if configured)
if [ -n "$DISCORD_WEBHOOK" ]; then
    if [ ${#failed_dbs[@]} -eq 0 ]; then
        curl -s -H "Content-Type: application/json" -X POST "$DISCORD_WEBHOOK" \
            -d "{\"embeds\": [{\"title\": \"💾 DarkStory LAND Backup Complete\", \"description\": \"Successfully created: dsl_backup_${TIMESTAMP}.tar.gz (MSSQL + SQLite)\", \"color\": 65280}]}" || true
    else
        curl -s -H "Content-Type: application/json" -X POST "$DISCORD_WEBHOOK" \
            -d "{\"embeds\": [{\"title\": \"⚠️ DarkStory LAND Backup Partial Failure\", \"description\": \"Failed databases: ${failed_dbs[*]}\", \"color\": 16711680}]}" || true
    fi
fi

echo ">>> [$(date)] DSL Backup Routine Completed Successfully."
[ ${#failed_dbs[@]} -eq 0 ]
