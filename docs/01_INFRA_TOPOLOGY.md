# 01. Infrastructure Architecture & Topology

## 1. Overview
The **DarkStory LAND** server stack runs on dedicated enterprise virtualization hardware with multi-tiered security, high-throughput kernel tuning, and an automated Docker microservices architecture protected by Cloudflare Edge Network.

```
                                  [ Cloudflare Global Anycast Network ]
                                     Zone: darkstoryland.com (SSL Full)
                                          │
                  ┌───────────────────────┼────────────────────────┐
                  ▼ (HTTPS: 443)          ▼ (HTTPS: 443)           ▼ (Raw TCP: 14400)
            [ Official Portal ]     [ WebClient (WSS) ]      [ Game Direct TCP ]
           darkstoryland.com        play.darkstoryland.com   s.darkstoryland.com
                  │                       │                        │
                  └───────────────────────┼────────────────────────┘
                                          ▼
                         [ Proxmox Hardware Node: pve-ridc-ol01 ]
                         [ Ubuntu 26.04 LTS VM (ID 2010): 168.222.2.57 ]
                                          │
                                 ┌────────┴────────┐
                                 │   UFW Firewall  │
                                 └────────┬────────┘
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  │              Docker Network: bridge           │
                  ├───────────────────────────────────────────────┤
                  │  1. darkstory_nginx     (Nginx Reverse Proxy) │
                  │  2. darkstory_web       (Node Portal/BO/API)  │
                  │  3. darkstory_webclient (HTML5 Canvas Engine) │
                  │  4. darkstory_mssql     (SQL Server 2019)     │
                  │  5. darkstory_server    (Wine 32-bit Cluster) │
                  │     ├── DistributeServer.exe (Login Gate)     │
                  │     ├── AgentServer.exe      (State/Channel)  │
                  │     └── MapServer.exe [1..45](45 World Zones) │
                  └───────────────────────────────────────────────┘
```

---

## 2. Hardware & Virtualization Specifications

| Specification | Configuration |
| :--- | :--- |
| **Hypervisor Node** | Proxmox Virtual Environment (`pve-ridc-ol01`) |
| **Virtual Machine ID** | `2010` (`darkstoryland-game-ol01`) |
| **Primary Public IP** | `168.222.2.57` |
| **Operating System** | Ubuntu Server 26.04.1 LTS (Linux Kernel 6.8.0-40) |
| **CPU Allocation** | 20 vCPUs (AMD EPYC Enterprise 64-bit) |
| **RAM Allocation** | 64 GB ECC DDR4 |
| **Storage Allocation**| 200 GB High-IOPS NVMe SSD |
| **Network Interface** | VirtIO Network Device (10 Gbps Uplink) |

---

## 3. Network Port Allocations & Routing

| Port | Service | Protocol | Exposure | Description |
| :--- | :--- | :--- | :--- | :--- |
| **22** | OpenSSH Server | TCP | Public (UFW) | Root & Ubuntu admin access via ED25519 key |
| **80** | Nginx Reverse Proxy | TCP | Public (UFW) | HTTP redirect to HTTPS (301 Permanent) |
| **443** | Nginx Reverse Proxy | TCP | Public (UFW) | HTTPS with TLS 1.2/1.3 and Cloudflare Real-IP |
| **3000** | Web Portal Engine | TCP | 127.0.0.1 | Official Portal, ItemMall, GM Back-Office |
| **8080** | WebClient Gateway | TCP | 127.0.0.1 | HTML5 Canvas WebSocket proxy |
| **9001** | Supervisord Console | TCP | 127.0.0.1 | Wine Server process manager web dashboard |
| **1433** | Microsoft SQL Server | TCP | 127.0.0.1 | SQL Server 2019 (Docker internal communication) |
| **14400** | DistributeServer | TCP | Public (UFW) | Client Authentication & Gateway Handshake |
| **14600-14602**| AgentServer | TCP | Public (UFW) | Channel Player Sessions & Character Sync |
| **17001-17003**| AgentServer Internal| TCP | 127.0.0.1 | Inter-process server routing |
| **18001-18050**| MapServer Zones | TCP | Public (UFW) | 45 Active Map Zones (Combat, NPCs, Portals) |
| **19001** | MonitoringServer | TCP | 127.0.0.1 | Server performance & crash monitoring |
| **20034** | RMToolServer | TCP | 127.0.0.1 | Remote Management Tool socket |
