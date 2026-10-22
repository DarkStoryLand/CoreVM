#!/usr/bin/env bash
# DarkStory LAND - Live Cluster Status & Health Check Script
set -e

echo "=================================================================="
echo "          DarkStory LAND - Cluster Health Check Suite             "
echo "=================================================================="

# 1. Check Docker Containers
echo ">>> [1/4] Docker Microservices Status:"
docker compose -f /opt/darkstory/docker/docker-compose.yml ps

# 2. Check MSSQL Connectivity
echo ""
echo ">>> [2/4] Database TCP Responsiveness (1433):"
if nc -z -w 3 127.0.0.1 1433; then
    echo "    [OK] Microsoft SQL Server is accepting TCP connections."
else
    echo "    [FAIL] Cannot connect to Microsoft SQL Server on port 1433."
fi

# 3. Check Game Process Supervisor
echo ""
echo ">>> [3/4] Supervisord Game Process Status:"
docker exec darkstory_server supervisorctl -s http://127.0.0.1:9001 -u admin -p "${SUPERVISOR_PASSWORD:-darkstoryland}" status || echo "    [WARN] Supervisord query failed."

# 4. Check Web Portal & SSL Proxy
echo ""
echo ">>> [4/4] Web Endpoints HTTP Status Codes:"
curl -k -s -o /dev/null -w "    Official Portal (https://darkstoryland.com): %{http_code}
" https://127.0.0.1/ -H "Host: darkstoryland.com" || true
curl -k -s -o /dev/null -w "    Back-Office (https://bo.darkstoryland.com): %{http_code}
" https://127.0.0.1/ -H "Host: bo.darkstoryland.com" || true
curl -k -s -o /dev/null -w "    WebClient Canvas (https://play.darkstoryland.com): %{http_code}
" https://127.0.0.1/ -H "Host: play.darkstoryland.com" || true
curl -k -s -o /dev/null -w "    REST API Status (https://api.darkstoryland.com/status): %{http_code}
" https://127.0.0.1/status -H "Host: api.darkstoryland.com" || true

echo "=================================================================="
