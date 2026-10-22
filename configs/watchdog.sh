#!/usr/bin/env bash
# ==============================================================================
# DarkStory LAND - High-Availability Auto-Recovery Watchdog
# Runs every 1 minute via crontab: * * * * * /opt/darkstory/docker/watchdog.sh
# Monitors: DistributeServer (14400), AgentServer (14600), Web (3000), WebClient (8080)
# Auto-heals: Automatically restarts crashed or frozen microservices
# ==============================================================================

SERVER_CONTAINER="darkstory_server"
WEB_CONTAINER="darkstory_web"
WEBCLIENT_CONTAINER="darkstory_webclient"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$SCRIPT_DIR/.env"
    set +a
fi
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"

restarted=()

check_port() {
    local host="$1"
    local port="$2"
    nc -z -w 3 "$host" "$port" 2>/dev/null
}

restart_service() {
    local service_name="$1"
    echo "!!! [$(date)] Alert: Service $service_name is UNRESPONSIVE! Triggering Auto-Restart..."

    case "$service_name" in
        web) docker restart "$WEB_CONTAINER" ;;
        webclient) docker restart "$WEBCLIENT_CONTAINER" ;;
        *) docker exec "$SERVER_CONTAINER" supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart "$service_name" ;;
    esac
    restarted+=("$service_name")

    # Discord Webhook Notification
    if [ -n "$DISCORD_WEBHOOK" ]; then
        curl -s -H "Content-Type: application/json" -X POST "$DISCORD_WEBHOOK" \
            -d "{\"embeds\": [{\"title\": \"🚨 Watchdog Auto-Restart Triggered\", \"description\": \"บริการ **$service_name** ไม่ตอบสนอง ทำการรีสตาร์ตอัตโนมัติแล้ว ณ $(date)\", \"color\": 16744448}]}"
    fi
}

# 1. Check DistributeServer Port 14400
check_port "127.0.0.1" 14400 || restart_service "distribute_server"

# 2. Check AgentServer Port 14600
check_port "127.0.0.1" 14600 || restart_service "agent_server"

# 3. Check Web Portal Port 3000
check_port "127.0.0.1" 3000 || restart_service "web"

# 4. Check WebClient Port 8080
check_port "127.0.0.1" 8080 || restart_service "webclient"

if [ ${#restarted[@]} -eq 0 ]; then
    echo ">>> [$(date)] Watchdog health check completed. All services HEALTHY."
else
    echo ">>> [$(date)] Watchdog health check completed. Restarted: ${restarted[*]}"
    exit 1
fi
