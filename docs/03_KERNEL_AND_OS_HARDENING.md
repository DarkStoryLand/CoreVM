# 03. Kernel Tuning, UFW Firewall & Host Hardening

## 1. Network & Kernel Parameter Tuning

The default Linux networking parameters are optimized for standard desktop or lightweight web traffic. DarkStory LAND runs high-throughput synchronous game sockets and database connections requiring elevated network buffers:

| Parameter | Default | Production Value | Purpose |
| :--- | :--- | :--- | :--- |
| `fs.file-max` | 65,536 | `2097152` | Prevents "Too many open files" errors across 45 MapServers |
| `net.core.somaxconn` | 128 | `65535` | Maximum socket listen backlog for burst player connections |
| `net.ipv4.tcp_max_syn_backlog`| 512 | `65535` | Queue depth for incoming half-open TCP connections |
| `net.ipv4.tcp_tw_reuse` | 0 | `1` | Allows reusing TIME_WAIT sockets for fast reconnection |
| `net.ipv4.tcp_fin_timeout` | 60 | `15` | Rapid reclamation of disconnected sockets |
| `vm.max_map_count` | 65,530 | `262144` | Required for SQL Server memory mapping and Wine threads |

---

## 2. UFW Firewall Configuration

Uncomplicated Firewall (UFW) is configured with a default-deny inbound policy, exposing only public game and web ports while isolating internal management interfaces to localhost.

### Applied UFW Rules:
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Remote Administration
sudo ufw allow 22/tcp comment 'SSH Remote Management'

# Web & Cloudflare Edge Services
sudo ufw allow 80/tcp comment 'HTTP Nginx Proxy'
sudo ufw allow 443/tcp comment 'HTTPS Nginx SSL Proxy'

# Public Game Socket Interfaces
sudo ufw allow 14400/tcp comment 'DistributeServer Gateway'
sudo ufw allow 14600:14605/tcp comment 'AgentServer User Channels'
sudo ufw allow 18001:18050/tcp comment 'MapServer 45 World Zones'

# Internal-Only Ports (Bound to 127.0.0.1 in Docker Compose)
# 1433 (MSSQL), 9001 (Supervisord), 3000 (Web Node), 8080 (WS Canvas)

sudo ufw enable
```

---

## 3. OpenSSH Access Hardening

1. **Password Authentication Disabled**:
   In `/etc/ssh/sshd_config`:
   ```ini
   PasswordAuthentication no
   ChallengeResponseAuthentication no
   PubkeyAuthentication yes
   PermitRootLogin prohibit-password
   ```
2. **Windows Client ACL Locking**:
   OpenSSH on Windows strictly rejects private keys with inherited permissions. Keys must be locked:
   ```powershell
   icacls C:\Users\X\.ssh\darkstory_root_ed25519 /inheritance:r
   icacls C:\Users\X\.ssh\darkstory_root_ed25519 /grant:r "$($env:USERNAME):(R)"
   ```
