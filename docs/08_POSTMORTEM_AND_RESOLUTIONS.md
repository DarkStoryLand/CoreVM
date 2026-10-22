# 08. Technical Post-Mortem & Resolved Gotchas

During the deployment of the DarkStory LAND production stack, eight critical engineering hurdles were diagnosed and resolved. This document serves as permanent institutional memory.

---

### Gotcha 1: MapServer Launch Argument Requirement
- **Symptom:** `MapServer.exe` showed as running under Wine, but did not open network sockets, and an X11 window titled "Error" appeared.
- **Root Cause:** Analysis of `MHFile.cpp` and `ServerSystem.cpp` revealed that `MapServer.exe` requires the Map Number (e.g. `17`) on the command line. Without it, a Win32 dialog `"Give Parameter as a Map Number"` opens and blocks execution.
- **Solution:** Re-engineered `entrypoint.sh` to dynamically enumerate all 45 maps from `serverlist.msl` and generate supervisor program definitions (`[program:map_1]`, `[program:map_2]`, etc.) passing the map ID argument.

---

### Gotcha 2: Legacy C++ Binary DB Password Compilation
- **Symptom:** `DistributeServer.exe` and `AgentServer.exe` failed with DB error dialogs on startup.
- **Root Cause:** In `[CC]ServerModule/DataBase.cpp`, legacy binaries have hardcoded SQL credentials `LOGINDBID = "GameSrv"` and `LOGINDBPASSWORD = "w8j2f@Z0H7#Xl"`. When `GameSrv` password differed or user was orphaned after DB restore, SQL Server rejected the connection with error 916 / login failure.
- **Solution:** Configured `GameSrv` in MSSQL with password `w8j2f@Z0H7#Xl` and fixed orphaned users in all 3 databases (`MHCMEMBER`, `MHGAME`, `MHLOG`). Added dynamic fallback in C++ codebase to read `DSL_DB_PASSWORD` for future rebuilds.

---

### Gotcha 3: Windows OpenSSH Key Permission Rejection
- **Symptom:** `ssh.exe` on Windows failed with `UNPROTECTED PRIVATE KEY FILE!` error.
- **Root Cause:** Windows default NTFS ACLs grant inheritance to SYSTEM, Administrators, and Users, violating OpenSSH strict permission checks.
- **Solution:** Stripped inheritance via `icacls <key> /inheritance:r` and granted exclusive read permission to the current user SID.

---

### Gotcha 4: PowerShell Carriage Return (`
`) Injection
- **Symptom:** Shell scripts generated via PowerShell failed on Linux with `$'\r': command not found`.
- **Root Cause:** Windows PowerShell injects CRLF line endings when redirecting text streams to SSH.
- **Solution:** Switched to transferring payloads via base64 encoded byte streams or stripping CRLF (`sed -i 's/\r$//'`) before execution.

---

### Gotcha 5: Wine 32-bit Debian/Ubuntu Package Layout
- **Symptom:** Wine container startup failed with `/entrypoint.sh: wineboot: command not found`.
- **Root Cause:** In Debian/Ubuntu multi-arch `wine32:i386`, binary loaders are located in `/usr/lib/wine/` and `/usr/lib/i386-linux-gnu/wine/` rather than `/usr/bin/`.
- **Solution:** Added automated symlinks and wrappers in `entrypoint.sh`:
  - `/usr/bin/wine` -> `/usr/lib/wine/wine`
  - `/usr/bin/wineserver` -> `/usr/lib/wine/wineserver`
  - `/usr/bin/wineboot` wrapper executing `wineboot.exe`
  - `/usr/bin/regedit` wrapper executing `regedit.exe`.

---

### Gotcha 6: SQL Server 2019 Tools Version (`sqlcmd`)
- **Symptom:** `sqlcmd: command not found` or SSL trust errors.
- **Root Cause:** MSSQL 2019 Linux container uses `/opt/mssql-tools18/bin/sqlcmd` which enforces strict TLS certificates by default.
- **Solution:** Updated all scripts to use `/opt/mssql-tools18/bin/sqlcmd` with `-C` (Trust Server Certificate) parameter.

---

### Gotcha 7: Docker Volumes Configuration Agility
- **Symptom:** Changing `entrypoint.sh` or `supervisord.conf` required an expensive 5-minute container image rebuild.
- **Root Cause:** Files were baked inside the Docker image during build.
- **Solution:** Added volume bind mounts in `docker-compose.yml`:
  ```yaml
  volumes:
    - /opt/darkstory/docker/entrypoint.sh:/entrypoint.sh
    - /opt/darkstory/docker/supervisord.conf:/etc/supervisor/conf.d/supervisord.conf:ro
  ```
  Modifications on the host now take effect instantly on container restart.
