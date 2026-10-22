#!/bin/bash
set -e

echo "======================================================================"
echo "    DarkStory LAND - Dedicated Linux Server Cluster Bootstrapper      "
echo "======================================================================"

mkdir -p /server/logs
chmod 777 /server/logs

# 1. Wait for MS SQL Server Container to be Ready
MSSQL_HOST=${DB_HOST:-mssql}
MSSQL_PORT=${DB_PORT:-1433}
: "${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD must be set (docker/.env)}"
: "${GAMESRV_PASSWORD:?GAMESRV_PASSWORD must be set (docker/.env)}"
: "${SUPERVISOR_PASSWORD:?SUPERVISOR_PASSWORD must be set (docker/.env)}"
# sqlcmd reads the password from the environment, so it never appears on a command line
export SQLCMDPASSWORD="${MSSQL_SA_PASSWORD}"

echo ">>> [1/5] Waiting for Microsoft SQL Server at ${MSSQL_HOST}:${MSSQL_PORT}..."
while ! nc -z -w 2 "$MSSQL_HOST" "$MSSQL_PORT"; do
    echo "    MSSQL is unavailable - sleeping 3 seconds..."
    sleep 3
done
echo ">>> [OK] MSSQL TCP connection established!"

# 2. Automated Database Initialization / Restoration
echo ">>> [2/5] Verifying DarkStory LAND Database Status..."
SQLCMD="/opt/mssql-tools18/bin/sqlcmd -S ${MSSQL_HOST},${MSSQL_PORT} -U sa -C"

# Test connection with sqlcmd
RETRIES=15
until $SQLCMD -Q "SELECT 1;" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo "    Waiting for MSSQL engine to accept queries ($RETRIES left)..."
    RETRIES=$((RETRIES-1))
    sleep 3
done

if [ $RETRIES -eq 0 ]; then
    echo ">>> [ERROR] Timed out waiting for MSSQL to accept queries."
    exit 1
fi

echo ">>> Running automated database restore script (if not already restored)..."
$SQLCMD -v GAMESRV_PASSWORD="${GAMESRV_PASSWORD}" -i /server/docker/db-init/restore_databases.sql

# 3. Configure Wine 32-bit Prefix and ODBC Integration
echo ">>> [3/5] Initializing Wine 32-bit Runtime Environment..."
export WINEARCH=win32
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all
export DISPLAY=:99

if [ ! -d "/root/.wine/drive_c" ]; then
    echo "    Creating new Wine 32-bit prefix..."
    wineboot -i
    wineserver -w
fi

# Configure Wine ODBC Registry to use unixODBC
cat << 'EOF' > /tmp/wine_odbc.reg
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\ODBC\ODBC.INI]

[HKEY_LOCAL_MACHINE\Software\ODBC\ODBC.INI\ODBC Data Sources]
"MHGame"="FreeTDS"
"MHCMember"="FreeTDS"
"MHLog"="FreeTDS"

[HKEY_LOCAL_MACHINE\Software\ODBC\ODBC.INI\MHGame]
"Driver"="C:\\windows\\system32\\odbc32.dll"
"Servername"="MSSQLServer"
"Database"="MHGame"
"Port"="1433"

[HKEY_LOCAL_MACHINE\Software\ODBC\ODBC.INI\MHCMember]
"Driver"="C:\\windows\\system32\\odbc32.dll"
"Servername"="MSSQLServer"
"Database"="MHCMember"
"Port"="1433"

[HKEY_LOCAL_MACHINE\Software\ODBC\ODBC.INI\MHLog]
"Driver"="C:\\windows\\system32\\odbc32.dll"
"Servername"="MSSQLServer"
"Database"="MHLog"
"Port"="1433"
EOF

wine regedit /tmp/wine_odbc.reg > /dev/null 2>&1 || true
wineserver -w

# 4. Generate one supervisord program per map server.
# MapServer.exe needs its map number as the argument; without it the process shows
# "Give Parameter as a Map Number" and exits. Default list = the MapServer records in
# SWorking/ServerSet/1/serverlist.msl. Override with MAP_SERVER_IDS.
echo ">>> [4/5] Generating map server programs..."
DEFAULT_MAP_IDS="1 2 5 6 7 8 9 10 11 12 13 14 15 17 18 19 20 21 22 25 28 35 37 39 40 42 59 60 61 66 67 68 69 70 72 73 75 95 96 101 102 104 105 106 108"
MAP_IDS="${MAP_SERVER_IDS:-$DEFAULT_MAP_IDS}"
MAPS_CONF=/etc/supervisor/conf.d/maps.conf
: > "$MAPS_CONF"
for id in ${MAP_IDS//,/ }; do
    case "$id" in
        ''|*[!0-9]*) echo "    Skipping invalid map id: $id"; continue ;;
    esac
    cat >> "$MAPS_CONF" << MAPEOF
[program:map_${id}]
directory=/server/SWorking
command=wine MapServer.exe ${id}
environment=DISPLAY=":99",WINEPREFIX="/root/.wine",WINEDEBUG="-all",WINEESYNC="1"
priority=40
autostart=true
autorestart=true
startsecs=10
stdout_logfile=/server/logs/map_${id}_stdout.log
stderr_logfile=/server/logs/map_${id}_stderr.log

MAPEOF
done
echo "    $(grep -c '^\[program:map_' "$MAPS_CONF") map servers configured."

# 5. Start Supervisord Process Supervisor
echo ">>> [5/5] Starting Server Cluster via Supervisord..."
echo "    Supervisord dashboard: http://127.0.0.1:9001 on the host (user admin, password = SUPERVISOR_PASSWORD)"
echo "======================================================================"

# Game servers read DSL_DB_USER / DSL_DB_PASSWORD (rebuilt exes; older exes use the compiled value)
export DSL_DB_USER=GameSrv
export DSL_DB_PASSWORD="${GAMESRV_PASSWORD}"

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
