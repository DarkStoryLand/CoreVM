#!/usr/bin/env bash
# ==============================================================================
# DarkStory LAND - Automated Database Backup & Retention Manager
# Runs every 6 hours via crontab: 0 */6 * * * /opt/darkstory/docker/auto_backup.sh
# Targets: MHCMember, MHGame, MHLog
# Retention: 7 Days (older backups automatically pruned)
#
# SQL Server writes each backup into the container's writable mssql_auto_backups
# volume; the script then copies it to docker/backups/ on the host, gzips it and
# removes the copy inside the container. Credentials come from docker/.env.
# ==============================================================================

set -eo pipefail

# Absolute paths so the script works from cron (whose working directory is $HOME)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
CONTAINER_BACKUP_DIR="/var/opt/mssql/auto_backups"
DB_CONTAINER="darkstory_mssql"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/.env"
    set +a
fi
: "${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD must be set in docker/.env}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"

mkdir -p "$HOST_BACKUP_DIR"

# Newer SQL Server images ship mssql-tools18 (needs -C), older ones mssql-tools
SQLCMD=$(docker exec "$DB_CONTAINER" sh -c 'ls /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd 2>/dev/null | head -1')
if [ -z "$SQLCMD" ]; then
    echo "!!! ERROR: sqlcmd not found in $DB_CONTAINER"
    exit 1
fi
SQLCMD_OPTS=""
case "$SQLCMD" in *tools18*) SQLCMD_OPTS="-C" ;; esac

echo ">>> [$(date)] Starting Automated Database Backup for DarkStory LAND..."

databases=("MHCMember" "MHGame" "MHLog")
failed_dbs=()

for db in "${databases[@]}"; do
    filename="${db}_backup_${TIMESTAMP}.bak"
    echo ">>> Backing up database: $db -> $filename"

    # Password via SQLCMDPASSWORD so it does not show up in the process list
    if docker exec -e SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" "$DB_CONTAINER" "$SQLCMD" $SQLCMD_OPTS \
        -S localhost -U sa -b \
        -Q "BACKUP DATABASE [$db] TO DISK = N'$CONTAINER_BACKUP_DIR/$filename' WITH COMPRESSION, CHECKSUM, STATS = 25;" \
        && docker cp "$DB_CONTAINER:$CONTAINER_BACKUP_DIR/$filename" "$HOST_BACKUP_DIR/$filename"; then

        docker exec "$DB_CONTAINER" rm -f "$CONTAINER_BACKUP_DIR/$filename"
        gzip -9 "$HOST_BACKUP_DIR/$filename"
        echo ">>> Successfully stored: $HOST_BACKUP_DIR/${filename}.gz"
    else
        echo "!!! ERROR: Failed to backup $db"
        failed_dbs+=("$db")
    fi
done

# Prune backups older than 7 days
echo ">>> Pruning backups older than 7 days..."
find "$HOST_BACKUP_DIR" -type f -name "*.bak.gz" -mtime +7 -delete

# Send Discord Notification
if [ -n "$DISCORD_WEBHOOK" ]; then
    if [ ${#failed_dbs[@]} -eq 0 ]; then
        curl -s -H "Content-Type: application/json" -X POST "$DISCORD_WEBHOOK" \
            -d "{\"embeds\": [{\"title\": \"💾 สำรองข้อมูลฐานข้อมูลสำเร็จ (Backup Complete)\", \"description\": \"สำรองฐานข้อมูล MHCMember, MHGame, MHLog เรียบร้อยแล้ว (รอบเวลา: $TIMESTAMP)\", \"color\": 65280}]}"
    else
        curl -s -H "Content-Type: application/json" -X POST "$DISCORD_WEBHOOK" \
            -d "{\"embeds\": [{\"title\": \"⚠️ สำรองข้อมูลล้มเหลว (Backup Failed)\", \"description\": \"เกิดข้อผิดพลาดในการสำรองฐานข้อมูล: ${failed_dbs[*]}\", \"color\": 16711680}]}"
    fi
fi

echo ">>> [$(date)] Database Backup Routine Completed."
[ ${#failed_dbs[@]} -eq 0 ]
