# 10. Outstanding Technical Roadmap & Action Tracker

This document tracks all 15 technical items prioritized by the core engineering team.

---

## 🔴 Priority 1: Critical (Financial & Player Impact)

### 1. In-Game Item & Cash Delivery Engine
- **Current State:** `mssqlBridge.js` enqueues SQL operations into `sql_sync_queue.json`.
- **Target Solution:** Active Node.js queue consumer using `mssql` (tedious) package. Parameterized queries updating `MHCMEMBER.dbo.chr_log_info.WebGold` and inserting into `MHGAME.dbo.TB_ShopItem (Idx, ItemIdx, ItemNum, Param1, Param2, RegDate)`.
- **Status:** Schema validated and documented.

### 2. Test Suite Integration & CI/CD
- **Current State:** 34 Batch A and 10 Batch B unit/integration test scripts created during security hardening.
- **Target Solution:** Migrate tests into `Web/test/` and `WebClient/test/`. Add GitHub Actions workflow (`.github/workflows/test.yml`) running on push/pull request.
- **Status:** Test scripts cataloged in scratch directory.

### 3. Offsite Backup Replication (Cloudflare R2)
- **Current State:** Backups saved locally in `/opt/darkstory/backup/auto_backups/`.
- **Target Solution:** Shell script calling AWS CLI / S3 API or Cloudflare MCP to push `.bak.gz` archives to Cloudflare R2 bucket `darkstory-patch-cdn`.
- **Status:** Documented with ready-to-run script.

---

## 🟠 Priority 2: Security & Hardening

### 4. Back-Office Multi-Factor Authentication (2FA TOTP)
- Implement `speakeasy` / `qrcode` TOTP authentication for GM accounts in Back-Office.
- Enforce IP allowlist in Nginx for `bo.darkstoryland.com`.

### 5. Client File Signature Asymmetric Verification
- Upgrade `security_manifest.sig` from symmetric HMAC to Ed25519 asymmetric signature. Client holds public key; server private key signs builds.

### 6. Client Auto-Patcher Integrity & CDN
- Serve patch manifest and chunks via HTTPS on `patch.darkstoryland.com` (Cloudflare R2).

### 7. Game Server Command Bounds Verification
- Add safety boundaries to GM commands: `/BAN`, `/DAMAGE`, `/MONEY`, `/LEVELUP` in server source code.

### 8. Game Port DDoS Protection (iptables connlimit)
- Apply `connlimit` / `hashlimit` on ports 14400 and 14600-14602 to prevent SYN flood attacks.

---

## 🟡 Priority 3: System & Maintainability

### 9. Persistent Session Store
- Migrate Web Portal express sessions from in-memory store to SQLite or Redis.

### 10. Database Migration for Web Metadata
- Transition `members.json` and static data to SQLite / MSSQL as player base exceeds 1,000 concurrent users.

### 11. Automated Log Rotation (`logrotate`)
- Configure `/etc/logrotate.d/darkstory` for MapServer 45 zones and container logs.

### 12. Dedicated Staging Environment
- Deploy isolated staging instance for testing recompiled C++ builds before production release.

---

## 🎮 Priority 4: In-Game Content & Economy

### 13. QuestScript.bin Decryption & Injection
- Decrypt active `QuestScript.bin` to integrate Daily (300-301), Weekly (302), and Songkran Festival (310) quests.

### 14. Web Player Leaderboards
- Query `MHGAME.dbo.TB_CHARACTER` for top levels, PvP kills, and guild power.

### 15. In-Game Economy Balance & Gold Sinks
- Automated SQL queries on `MHLOG` tracking money velocity and dupe detection.
