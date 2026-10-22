# 06. DarkStory LAND - Automation, Zero-Cost Backup & Security Operations

## 1. Zero-Cost Backup Architecture (100% Free & Self-Hosted)

> [!NOTE]
> ระบบสำรองข้อมูลทั้งหมดของ DarkStory LAND ทำงานแบบ Zero-Cost Architecture 100% ไม่พึ่งพา Cloudflare R2, AWS S3 หรือบริการที่มีค่าใช้จ่ายหรือต้องผูกบัตรเครดิต (No Billing Required)

### 1.1 Remote Automated Backup (`/opt/darkstory/docker/auto_backup.sh`)
- **ความถี่**: ทุก 6 ชั่วโมง (`0 */6 * * *`) ผ่าน Crontab บน VM Host
- **ฐานข้อมูลที่สำรอง**:
  1. **MSSQL Database Cluster**:
     - `MHCMember` (บัญชีผู้เล่น, ยอดเงิน WebGold, ข้อมูลตัวละคร)
     - `MHGame` (ไอเทม, กระเป๋า, คลัง, ไอเทมมอลล์)
     - `MHLog` (บันทึกธุรกรรมและการเล่น)
     - สำรองด้วยคำสั่ง Native SQL Server: `WITH COMPRESSION, CHECKSUM, STATS = 25`
  2. **SQLite Web Database**:
     - `darkstory_web.db` (เซสชันผู้เล่น, ประวัติการซื้อไอเทม, คำสั่งซื้อ, ประวัติการเติมเงิน, คิวส่งไอเทม)
     - สำรองแบบ Online Snapshot ด้วย `sqlite3 .backup` + gzip compression
- **การจัดเก็บ**: บันทึกลงในไฟล์ Archive รวม: `/opt/darkstory/backups/dsl_backup_<TIMESTAMP>.tar.gz`
- **Retention บนเซิร์ฟเวอร์**: ลบไฟล์สำรองที่อายุเกิน 7 วันอัตโนมัติ

### 1.2 Local Offsite Backup Pull (เครื่องออฟฟิศ / แอดมิน)
- **สคริปต์ Windows**: `F:\DarkStory\CoreVM\scripts\pull_remote_backups.bat`
- **สคริปต์ Linux/Mac**: `F:\DarkStory\CoreVM\scripts\pull_remote_backups.sh`
- **การทำงาน**:
  - ดึงไฟล์ `.tar.gz` ล่าสุดจาก VM ลงมาเก็บไว้ที่ฮาร์ดไดรฟ์ภายในเครื่อง (`F:\DarkStory\Backups`) ผ่าน SSH Key (`darkstory_root_ed25519`)
  - จัดเก็บไฟล์สำรองย้อนหลังในเครื่อง Local 30 วันอัตโนมัติ
  - **ต้นทุน**: 0 บาท (Free 100%)

---

## 2. Game Port & Network Protection (iptables Rate Limiting)

เพื่อป้องกัน Botnet SYN Flood และการเปิด Connection รบกวนเซิร์ฟเวอร์เกม ได้มีการตั้งค่า Host Firewall ด้วย `iptables`:

```bash
# จำกัด Connection ไปยัง Distribute Server (Login Port 14400) ไม่เกิน 25 ต่อ IP
iptables -I ufw-user-input 1 -p tcp --dport 14400 -m connlimit --connlimit-above 25 --connlimit-mask 32 -j REJECT

# จำกัด Connection ไปยัง Map/Agent Servers (Ports 14600-14605) ไม่เกิน 25 ต่อ IP
iptables -I ufw-user-input 2 -p tcp -m multiport --dports 14600:14605 -m connlimit --connlimit-above 25 --connlimit-mask 32 -j REJECT

# บันทึกกฎถาวร
iptables-save > /etc/iptables/rules.v4
```

---

## 3. Log Rotation Engine (45 MapServers + System Logs)

ติดตั้ง Logrotate ไว้ที่ `/etc/logrotate.d/darkstory`:
- **ไฟล์ที่ตรวจสอบ**:
  - `/opt/darkstory/docker/logs/*.log` (Supervisord, Distribute, Agent, 45 MapServers)
  - `/opt/darkstory/logs/*.log` (Nginx, Web, Watchdog)
  - `/opt/darkstory/server/SWorking/Log/*.txt` (Log เกมจาก Wine)
- **การจัดการ**:
  - หมุนเวียนรายวัน (`daily`)
  - บีบอัดไฟล์เก่า (`compress`, `delaycompress`)
  - เก็บย้อนหลัง 7 วัน (`rotate 7`)
  - ปลอดภัยต่อ Process ที่เปิดไฟล์ค้างไว้ (`copytruncate`)

---

## 4. Back-Office Two-Factor Authentication (2FA TOTP)

- ระบบ 2FA พัฒนาขึ้นด้วยมาตรฐาน RFC 6238 TOTP (Time-Based One-Time Password)
- ทำงานแบบ 100% Offline ภายใน Node.js Crypto Engine
- ใช้งานได้กับ Google Authenticator, Microsoft Authenticator, 1Password
- แอดมินและทีมงานสามารถเปิดใช้งานผ่าน `/api/bo/auth/2fa/setup` และ `/api/bo/auth/2fa/enable`
- เมื่อเปิดใช้งานแล้ว การล็อกอินเข้าจัดการระบบจะต้องระบุรหัส 6 หลักเสมอ
