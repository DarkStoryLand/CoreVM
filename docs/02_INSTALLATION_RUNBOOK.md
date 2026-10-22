# 02. End-to-End Installation & Deployment Runbook

## Phase 1: Host Operating System Preparation

### 1. Update Package Repositories
```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl wget git unzip htop iotop net-tools ufw ca-certificates gnupg
```

### 2. Configure High-Performance Kernel Parameters
Append the following parameters to `/etc/sysctl.conf`:
```ini
fs.file-max = 2097152
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
vm.max_map_count = 262144
```
Apply immediately:
```bash
sudo sysctl -p
```

### 3. Configure Security Limits
Add to `/etc/security/limits.conf`:
```
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
```

---

## Phase 2: Docker Engine Installation

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

---

## Phase 3: Project Directory Structure Setup

Create the standardized layout in `/opt/darkstory/`:
```bash
sudo mkdir -p /opt/darkstory/{docker,db,server,web,webclient,backup,logs}
sudo mkdir -p /opt/darkstory/backup/auto_backups
sudo chmod -R 777 /opt/darkstory/backup
sudo chmod -R 777 /opt/darkstory/logs
```

---

## Phase 4: Database Deployment & Restoration

1. Copy database backup files (`MHCMEMBER.bak`, `MHGAME.bak`, `MHLOG.bak`) into `/opt/darkstory/db/`.
2. Start the database service:
   ```bash
   cd /opt/darkstory/docker
   docker compose up -d mssql
   ```
3. Run the automated database initialization script:
   ```bash
   docker exec -i darkstory_mssql /opt/mssql-tools18/bin/sqlcmd      -S localhost -U sa -P "${MSSQL_SA_PASSWORD}" -C      -i /var/opt/mssql/init_db/restore_databases.sql
   ```
4. Verify all databases are `ONLINE` and RCSI (`READ_COMMITTED_SNAPSHOT`) is enabled.

---

## Phase 5: Nginx SSL & Subdomains Proxy Deployment

1. Generate self-signed origin certificate (compatible with Cloudflare SSL Full mode) or install Let's Encrypt:
   ```bash
   sudo mkdir -p /etc/letsencrypt/live/darkstoryland.com
   sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048      -keyout /etc/letsencrypt/live/darkstoryland.com/privkey.pem      -out /etc/letsencrypt/live/darkstoryland.com/fullchain.pem      -subj "/CN=*.darkstoryland.com/O=DarkStory LAND/C=TH"
   ```
2. Start Nginx, Web, and WebClient containers:
   ```bash
   docker compose up -d nginx web webclient
   ```

---

## Phase 6: Game Server Cluster Launch

1. Place server binaries and assets into `/opt/darkstory/server/SWorking/`.
2. Launch the Wine 32-bit container:
   ```bash
   docker compose up -d server
   ```
3. Inspect startup logs:
   ```bash
   docker logs --tail 50 darkstory_server
   ```
4. Verify all map processes via supervisorctl:
   ```bash
   docker exec darkstory_server supervisorctl -s http://127.0.0.1:9001 -u admin -p "${SUPERVISOR_PASSWORD}" status
   ```
