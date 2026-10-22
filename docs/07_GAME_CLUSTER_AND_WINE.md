# 07. Game Server Cluster & Wine 32-bit Architecture

## 1. Overview
The game server binaries (`DistributeServer.exe`, `AgentServer.exe`, `MapServer.exe`) are 32-bit Windows PE executables compiled against MFC 7.1 and DirectX 8.1. They run headlessly on Linux using a customized Wine 32-bit runtime with Xvfb virtual display emulation and FreeTDS unixODBC bridging.

---

## 2. Server Cluster Topology

```
[ Client Gateway ]  ──> DistributeServer.exe (Port 14400)
                              │  (Authenticates against MHCMEMBER)
                              ▼
                        AgentServer.exe (Ports 14600-14602)
                              │  (Manages Player State & Channel Balance)
                              ▼
                        MapServer.exe <map_id> (Ports 18001-18050)
                              (Simulates Combat, Monsters & NPCs across 45 Zones)
```

---

## 3. MapServer Launch Requirement
**CRITICAL:** `MapServer.exe` MUST be executed with its designated Map Number as the first command-line argument:
```bash
wine MapServer.exe 17
```
If launched without arguments, `MapServer.exe` triggers a Win32 GUI message box displaying:
`"Give Parameter as a Map Number"` and halts execution.

In our production stack, `entrypoint.sh` automatically reads `MAP_SERVER_IDS` and generates 45 distinct program blocks in `/etc/supervisor/conf.d/maps.conf`:
```ini
[program:map_17]
directory=/server/SWorking
command=wine MapServer.exe 17
environment=DISPLAY=":99",WINEPREFIX="/root/.wine",WINEDEBUG="-all",WINEESYNC="1"
priority=40
autostart=true
autorestart=true
startsecs=10
```

---

## 4. Active World Maps (45 Zones)
`1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 25, 28, 35, 37, 39, 40, 42, 59, 60, 61, 66, 67, 68, 69, 70, 72, 73, 75, 95, 96, 101, 102, 104, 105, 106, 108`
