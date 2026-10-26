# 09. Day-2 Operations & Emergency Runbook

For the existing local `dsl-test` VM, its private stage profiles, cold-start checks,
and the difference from the CoreKeys endpoint, use [Local DSL test startup](11_LOCAL_DSL_TEST_STARTUP.md).

## 1. Common Operational Commands

### Checking Stack Status
```bash
cd /opt/darkstory/docker
docker compose ps
```

### Inspecting Live Game Server Logs
```bash
# View DistributeServer (Login Gateway)
docker exec darkstory_server tail -f /server/logs/distribute_stdout.log

# View AgentServer (Channel State)
docker exec darkstory_server tail -f /server/logs/agent_stdout.log

# View MapServer Zone 17
docker exec darkstory_server tail -f /server/logs/map_17_stdout.log
```

### Managing Game Processes via Supervisord
```bash
# Check status of all 45 maps
docker exec darkstory_server supervisorctl -s http://127.0.0.1:9001 -u admin -p "${SUPERVISOR_PASSWORD}" status

# Restart a specific map server without downtime to other zones
docker exec darkstory_server supervisorctl -s http://127.0.0.1:9001 -u admin -p "${SUPERVISOR_PASSWORD}" restart map_17
```

---

## 2. Database Backup & Disaster Recovery

### Manual Backup On-Demand
```bash
sudo /opt/darkstory/docker/auto_backup.sh
```

### Restoring from a Backup Archive
```bash
# 1. Uncompress backup
gunzip -c /opt/darkstory/backup/auto_backups/MHGAME_backup_YYYYMMDD_HHMMSS.bak.gz > /opt/darkstory/backup/restore_target.bak

# 2. Execute SQL Restore
docker exec -i darkstory_mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "${MSSQL_SA_PASSWORD}" -C -Q "
ALTER DATABASE [MHGAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [MHGAME] FROM DISK = '/var/opt/mssql/backup/restore_target.bak' WITH REPLACE;
ALTER DATABASE [MHGAME] SET READ_COMMITTED_SNAPSHOT ON;
ALTER DATABASE [MHGAME] SET MULTI_USER;
"
```
