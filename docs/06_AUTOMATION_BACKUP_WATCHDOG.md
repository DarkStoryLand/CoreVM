# 06. Automated Backups & System Watchdog Daemon

## 1. Automated Database Backup Engine (`auto_backup.sh`)

Located at `/opt/darkstory/docker/auto_backup.sh`.  
Runs every 6 hours via system cron (`0 */6 * * *`).

### Operational Logic:
1. Generates timestamped SQL backups (`.bak`) using native SQL Server compression (`WITH COMPRESSION`).
2. Applies secondary maximum gzip compression (`gzip -f -9`) to minimize storage footprint (~80% reduction).
3. Moves compressed archives to `/opt/darkstory/backup/auto_backups/`.
4. Automatically purges archives older than 7 days (`find -mtime +7 -delete`).

### Retention & Compression Metrics:
- `MHCMEMBER`: ~8 MB uncompressed -> ~1.3 MB `.bak.gz`
- `MHGAME`: ~12 MB uncompressed -> ~2.0 MB `.bak.gz`
- `MHLOG`: ~1 MB uncompressed -> ~440 KB `.bak.gz`
- Backup execution time: ~0.16 seconds total.

---

## 2. Cluster Health Watchdog Daemon (`watchdog.sh`)

Located at `/opt/darkstory/docker/watchdog.sh`.  
Runs every 5 minutes via system cron (`*/5 * * * *`).

### Self-Healing Checks:
1. **MSSQL TCP Check**: Validates port 1433 responsiveness using `nc -z -w 3`. Auto-restarts container if unresponsive.
2. **Supervisord Status Check**: Queries `supervisorctl status`.
3. **Game Process Health**: Validates that `distribute_server`, `agent_server`, and active `map_*` processes are in `RUNNING` state. If a process enters `FATAL` or `STOPPED`, triggers automatic `supervisorctl restart <service>`.
4. **Audit Logging**: Logs all actions to `/opt/darkstory/logs/watchdog.log`.
