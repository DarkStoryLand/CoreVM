# เปิดเซิร์ฟเวอร์ local `dsl-test` และตรวจหาสาเหตุที่ต่อไม่ได้

ตรวจจากเครื่องจริงวันที่ 26 ตุลาคม 2026 (Asia/Bangkok) โดยแชท Fixed Bugs ประสานกับ Feature (Root) และ SERVER เอกสารนี้ใช้กับ VM local ที่มีอยู่แล้ว ไม่ใช่ขั้นตอนติดตั้งใหม่

## Service เดิมเปิดที่ไหน ใช้โปรแกรมอะไร

เปิด VM บน **Windows ด้วย VMware Workstation** โดยเลือกไฟล์ `F:\DarkStory\VMs\dsl-test\dsl-test.vmx` หรือใช้ `D:\VMware\VMware Workstation\vmrun.exe` ตามขั้นตอนข้างล่าง จากนั้นบริหารบริการผ่าน **SSH เข้า Ubuntu VM** ไม่ใช่เปิดไฟล์ EXE เกมบน Windows host

ลำดับที่ตรวจจริงคือ **VMware → Ubuntu/systemd → Docker → container เดิม → `/stage/start.sh` → Xvfb + Supervisor → Wine รัน native EXE**:

| ชั้น | โปรแกรม / service | ที่อยู่ / วิธีบริหาร |
| --- | --- | --- |
| VM บน Windows | VMware Workstation / `vmrun.exe` | exact VMX ข้างบน |
| Docker daemon ใน Ubuntu | `docker.service` (enabled, active) | `/usr/lib/systemd/system/docker.service`; ตรวจ `systemctl is-active docker` |
| DB และเกม | Docker containers ตามตาราง profile | ใช้ `docker start` กับของเดิม ไม่สร้างใหม่ |
| ตัวเริ่มใน game container | bash + stage startup script | host NPC source `/home/dsl/origin-npc-qa-20261024/start.sh`; working directory `/server/SWorking` |
| จอเสมือนที่ native console ต้องใช้ | `Xvfb :99` | NPC ใช้ `-screen 0 1024x768x16 -nolisten tcp` |
| ตัวคุม process เกม | `supervisord` / `supervisorctl` | `/stage/supervisord.conf` ใน container |
| โปรแกรมเกมจริง | `DistributeServer.exe`, `AgentServer.exe`, `MapServer.exe` ผ่าน Wine | NPC source อยู่ `/home/dsl/origin-npc-qa-20261024/SWorking/` |

**IP เป็นค่าที่ต้องค้นจาก VM ปัจจุบัน ไม่ใช่ตัวบอกว่าใช้โปรแกรมอะไรเปิด service** หลัง restart ให้หา IP ปัจจุบันและยืนยัน identity ก่อน รอบที่ตรวจนี้ DHCP ออก IP เดิม 135 และ `getGuestIPAddress` ยืนยันตรงกัน ไม่พบหลักฐานว่า IP เปลี่ยนในรอบนี้ ปัญหาที่พบคือ VM ปิด, container ไม่ autostart และ Xvfb มี runtime file ค้าง

## แยกปลายทางก่อนเริ่ม

| ปลายทาง | IP | หน้าที่ / จุดตรวจ |
| --- | --- | --- |
| เครื่องที่ระบุใน CoreKeys และ `Client/Ini/ServerList.ini` | `168.222.2.57` | คนละเครื่องกับ VM local; ก่อนเริ่มงานพบ TCP 22, 1433, 14400, 14600, 18001 เปิด |
| VM `dsl-test` | `192.168.188.135` | local private stage บน VMware NAT; SSH 22 |
| VMnet8 บน Windows host | `192.168.188.1` | adapter ฝั่ง host ไม่ใช่ IP เกม |
| loopback | `127.0.0.1` | หมายถึงเครื่องที่ process ทำงานอยู่ ต้องดูบริบท; ไม่ใช่ชื่อแทน `dsl-test` |

การที่ 168 ตอบ ไม่ได้แปลว่า local พร้อม และ local ปิดก็ไม่ได้แปลว่า 168 ล่ม ตรวจ endpoint/profile ที่ client ใช้จริงก่อนสรุปสาเหตุ ชื่อ `dsl-test` ต้องยืนยันจาก SSH และ host key ที่บันทึกไว้ ไม่เดาจากชื่อไฟล์เพียงอย่างเดียว

| profile local | auth / gateway TCP | container เกม | container ฐานข้อมูล |
| --- | --- | --- | --- |
| `isolated-npc` | 34400 / 34600 | `dsl-origin-npc-qa-20261024` | `dsl-origin-npc-mssql-20261024` |
| `legacy-stage` | 24400 / 24600 | `dsl-origin-server-20261023` | `dsl-origin-mssql-20261023` |
| `isolated-progression` | 35400 / 35600 | ตรวจชื่อปัจจุบันกับ Root ก่อน | ตรวจชื่อปัจจุบันกับ Root ก่อน |

Root ใช้ isolated-npc ในงาน QA ปัจจุบัน แต่บาง source ตั้ง default เป็น legacy-stage อย่าเลือกชุดจาก default เพียงอย่างเดียว ไม่จำเป็นต้องเปิดทุกชุดเพื่อให้ชุดเดียวใช้งานได้ DB ของสองชุดแรกไม่มี host port ที่ publish ออกมา จึงใช้การตรวจ TCP 1433 บน host แทน DB readiness ภายในไม่ได้

## สิ่งที่พบจริงและขอบเขตการกู้คืน

1. ก่อนเปิด `vmrun list` ไม่มี VMX ของ DSL และ `getGuestIPAddress` ตอบว่า VM ไม่ได้เปิด มี VM ของโครงการอื่นทำงานอยู่หนึ่งเครื่องและต้องคงไว้
2. สั่งเปิดเฉพาะ VMX ของ DSL แบบ `nogui` สำเร็จ ระยะแรก Tools ยังไม่พร้อมและ SSH timeout ได้ จึงต้องรอแบบมีเวลาจำกัด ไม่เปิด VM ซ้ำหรือ reset ทันที
3. DHCP ออก lease ใหม่ให้ MAC `00:0c:29:49:73:dd` เป็น IP เดิม `192.168.188.135`; SSH แบบ strict host verification สำเร็จ และ hostname เป็น `dsl-test`
4. `ssh` และ `docker` active แต่ container ทั้งสี่ในตารางแรกเป็น `exited`, `restartPolicy=no`, exit code 255 จากรอบก่อน จึงไม่เปิดตามการบูต VM ตัวเลข 255 อย่างเดียวไม่พิสูจน์สาเหตุที่ VM ดับในครั้งก่อน
5. NPC supervisor ตั้ง `distribute`/`agent` ให้ autostart แต่ map programs ตั้ง autostart=false การเปิด container จึงยังไม่เท่ากับเปิดแผนที่พร้อมเล่น ส่วน legacy ตั้ง map1/map69 autostart=true

สถานะบริการเกมหลังขั้นตอนกู้คืนต้องอ้างอิงบันทึกผลท้ายเอกสาร ห้ามถือว่า VM running หรือพอร์ต gateway เปิดเป็นหลักฐานว่า login/เข้าแผนที่ผ่านแล้ว

## 1. ตรวจและเปิด VM ที่ถูกตัว

ใช้ PowerShell บน Windows host คำสั่งต่อไปนี้ไม่มีรหัสผ่าน:

```powershell
$dslVmrun = 'D:\VMware\VMware Workstation\vmrun.exe'
$dslVmx = 'F:\DarkStory\VMs\dsl-test\dsl-test.vmx'
Test-Path -LiteralPath $dslVmrun
Test-Path -LiteralPath $dslVmx
& $dslVmrun list
```

ต้องได้ path ถูกต้องทั้งคู่ อ่านรายการ VM ที่กำลังทำงานก่อน ถ้า exact DSL VMX อยู่ในรายการแล้ว ข้ามคำสั่ง start ห้ามสั่ง stop/reset VM อื่นเพื่อแก้ DSL

```powershell
# ใช้เฉพาะเมื่อ exact DSL VMX ยังไม่ทำงาน
& $dslVmrun start $dslVmx nogui
if ($LASTEXITCODE -ne 0) { throw 'DSL VM start failed; inspect bounded diagnostics' }
& $dslVmrun list
& $dslVmrun checkToolsState $dslVmx
& $dslVmrun getGuestIPAddress $dslVmx
Test-NetConnection 192.168.188.135 -Port 22 -InformationLevel Quiet
```

เมื่อ Tools พร้อม ให้รับ IP ปัจจุบันเป็นตัวแปรแทนการจำเลขเดิม:

```powershell
$dslGuestIP = (& $dslVmrun getGuestIPAddress $dslVmx).Trim()
if ($LASTEXITCODE -ne 0 -or $dslGuestIP -notmatch '^192\.168\.188\.\d{1,3}$') {
    throw 'Guest IP unavailable/unexpected; verify exact-VM DHCP lease before proceeding'
}
```

ถ้า Tools ยังไม่พร้อม ให้เทียบ MAC ของ ethernet0 ใน exact VMX กับ lease ใหม่ใน `C:\ProgramData\VMware\vmnetdhcp.leases` อ่านเฉพาะ block ที่ MAC ตรงกัน อย่าใช้ lease เก่าในไฟล์สำรองเป็นหลักฐาน IP ปัจจุบัน หาก IP เปลี่ยนจริงยังต้องตรวจ Docker host-IP bindings และ endpoint ที่ client ใช้ด้วย การเปลี่ยน IP ไม่ได้ทำให้ service เดิมย้ายหรือเปลี่ยนโปรแกรมเปิด

`installed` จาก checkToolsState ยังไม่ใช่หลักฐานว่า Tools กำลังทำงาน หลัง cold boot ให้ตรวจซ้ำห่างกันประมาณ 5–10 วินาที มีขอบเขตประมาณ 3 นาที หาก Tools ยังตอบไม่ได้แต่ SSH พร้อม ให้ยืนยันด้วย strict SSH ต่อได้ หากได้ IP ใหม่ ห้ามแก้ client/known_hosts หรือสแกนเครื่องอื่นอัตโนมัติ ให้ตรวจ DHCP lease ที่ตรง MAC และ VM identity ก่อน

VMX ก่อนเปิดรอบนี้ SHA-256 `f5e33f55137789c070b13dc5b4cce590aeb3a469f6592eaa0d819c1f020e7de7` เป็นหลักฐานย้อนหลัง ไม่ใช่ค่าที่บังคับให้เหมือนตลอดไป เพราะ VMware อาจบันทึก metadata หลังเปิด

## 2. SSH โดยใช้ reference เดิม

ใช้ reference ของ checkout ที่กำลังทำงานจริง ไม่คัดลอก private key ลง repo และไม่เปิดไฟล์ inventory ที่มีค่าลับเพื่อแสดงผล ตัวอย่างนี้อ้างอิง checkout ที่ตรวจจริงในวันที่ระบุ:

```powershell
$dslRoot = 'F:\DarkStory\_worktrees\DSL-root-content-qa-20261026'
$dslRefs = (Get-Content -Raw -LiteralPath (Join-Path $dslRoot 'Keys\dsl-key-references.v1.json') | ConvertFrom-Json).references
$dslIdentity = $dslRefs.'dsl.stage.ssh'.path
$dslKnownHosts = $dslRefs.'dsl.stage.knownHosts'.path
if (!(Test-Path -LiteralPath $dslIdentity) -or !(Test-Path -LiteralPath $dslKnownHosts)) {
    throw 'Existing SSH identity/known-host reference missing'
}
$dslSshArgs = @('-i', $dslIdentity, '-o', "UserKnownHostsFile=$dslKnownHosts",
    '-o', 'StrictHostKeyChecking=yes', '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=5', "dsl@$dslGuestIP")
$dslHostname = & ssh @dslSshArgs hostname
if ($LASTEXITCODE -ne 0 -or $dslHostname.Trim() -ne 'dsl-test') {
    throw 'Strict SSH / expected hostname failed; stop before container operations'
}
```

อย่าพิมพ์ `$dslRefs`, environment, private key หรือไฟล์ config ทั้งฉบับ ห้ามใช้ StrictHostKeyChecking=no, ลบ known_hosts เพื่อผ่าน error, ส่ง guest password บน command line หรือสร้าง key ใหม่เพื่อกลบปัญหาที่เกิดขึ้น ถ้า timeout ให้ตรวจ VM/เครือข่าย; ถ้า host key mismatch ให้หยุดตรวจ identity; ถ้า Permission denied ให้ตรวจ reference และสิทธิ์ของไฟล์เดิม

## 3. ตรวจ container และเลือกชุดที่จะเปิด

ตัวอย่างสถานะที่ปลอดภัยกว่าการ dump `docker inspect` ทั้งก้อน:

```powershell
& ssh @dslSshArgs 'systemctl is-active ssh docker'
& ssh @dslSshArgs 'docker inspect --format "{{.Name}} {{.State.Status}} {{.HostConfig.RestartPolicy.Name}}" dsl-origin-npc-mssql-20261024 dsl-origin-npc-qa-20261024 dsl-origin-mssql-20261023 dsl-origin-server-20261023'
```

ยืนยัน profile ที่ต้องการกับผู้ดูแล Root และตรวจว่าไม่มี QA/session ที่กำลังใช้ชุดนั้น การ start container ที่มีอยู่ต้องแยกจาก provision/deploy/restore/fixture migration อย่าใช้ `docker compose up` จากคู่มือเก่าที่สร้างชุดใหม่แทนการ start ชุด stage เดิม

ลำดับสำหรับชุด NPC ที่มีอยู่: DB → ตรวจ DB พร้อม → game container → ตรวจ supervisor → เปิดเฉพาะ map ที่ยืนยันสำหรับรอบนั้น → ตรวจ TCP → ประสาน Root ทดสอบเกม ลำดับนี้ไม่อนุญาตให้เปิด map ทั้งหมดหรือ SQL writes โดยอัตโนมัติ

```powershell
# หลังยืนยันขอบเขตกับ Root แล้วเท่านั้น; ข้ามถ้า running อยู่
& ssh @dslSshArgs 'docker start dsl-origin-npc-mssql-20261024'
# ตรวจ DB readiness ภายใน container ด้วยวิธีเดิมที่ไม่พิมพ์ credential
# เมื่อ DB พร้อมแล้วจึงใช้:
& ssh @dslSshArgs 'docker start dsl-origin-npc-qa-20261024'
& ssh @dslSshArgs 'docker exec dsl-origin-npc-qa-20261024 supervisorctl -c /stage/supervisord.conf status'
```

อย่าใช้ `supervisorctl start all` หรือ restart all: NPC config มีหลาย map ที่ตั้งใจไม่ autostart หาก map1 ยัง STOPPED ต้องยืนยันขอบเขตและ readiness ก่อน `start map1`; การเดินทางไป map อื่นต้องเตรียม map ปลายทางแยกต่างหาก

ไม่เปลี่ยน restart policy เป็น always โดยพลการ เพราะจะทำให้ชุด QA ที่ตั้งใจหยุดกลับมารันหลัง host/VM reboot และไม่ได้แก้ลำดับ DB/game readiness ให้ถูกต้อง

## 3a. ตรวจ DB readiness โดยไม่เผย credential

รันผ่าน strict SSH ชุดเดิม ตัวอย่างนี้อ่าน credential ภายใน VM แล้วส่งผ่าน environment ของ process ไม่ใส่ค่า credential ใน argument หรือผลลัพธ์ ใช้เฉพาะ SELECT:

```powershell
$dslDbCheck = @'
import json, os, socket, subprocess
assert socket.gethostname() == 'dsl-test'
db = 'dsl-origin-npc-mssql-20261024'
p = subprocess.run(['docker','inspect',db], capture_output=True, text=True, check=True)
obj = json.loads(p.stdout)[0]
values = dict(x.split('=',1) for x in obj['Config']['Env'] if '=' in x)
env = os.environ.copy()
env['SQLCMDPASSWORD'] = values['MSSQL_SA_PASSWORD']
query = "SET NOCOUNT ON; SELECT name, state_desc FROM sys.databases WHERE name IN ('MHCMEMBER','MHGAME','MHLOG');"
p = subprocess.run(['docker','exec','-i','-e','SQLCMDPASSWORD',db,
    '/opt/mssql-tools18/bin/sqlcmd','-S','localhost','-U','sa','-C','-b',
    '-h','-1','-W','-l','3','-t','3'], input=query, env=env,
    capture_output=True, text=True, timeout=8)
rows = [line.split() for line in p.stdout.splitlines()]
online = {x[0] for x in rows if len(x)==2 and x[0] in {'MHCMEMBER','MHGAME','MHLOG'} and x[1]=='ONLINE'}
print(json.dumps({'queryExit':p.returncode, 'allThreeOnline':online=={'MHCMEMBER','MHGAME','MHLOG'}}))
raise SystemExit(0 if p.returncode==0 and len(online)==3 else 2)
'@
$dslDbCheck | & ssh @dslSshArgs 'python3 -'
if ($LASTEXITCODE -ne 0) { throw 'DB not ready; do not start the game container yet' }
```

รอบนี้พร้อมในครั้งที่สอง ถ้ายังไม่พร้อม ให้รอและลองเฉพาะ read check แบบจำกัดเวลา ห้าม retry start/recreate/reset DB เป็นวงไม่สิ้นสุด

## 3b. กรณีหลัง restart: Xvfb หาย แต่มี X99 lock/socket ค้าง

อาการที่ยืนยันรอบนี้: container running แต่ distribute/agent FATAL; stderr ระบุ read page fault ที่ `0x000002D8`, backtrace บนสุดอยู่ใน `mhconsole`; ภายใน container ไม่มี Xvfb, PID 7 ใน `.X99-lock` ไม่มี process แล้ว และ Unix socket ต่อไม่ได้ หลังแก้เฉพาะจอเสมือนและเริ่มโปรแกรมเดิม บริการทั้งสาม RUNNING จึงมีหลักฐานก่อน/หลังรองรับสาเหตุ

ก่อนลบอะไร ต้องอยู่ใน exact NPC container, ไม่มีผู้ใช้งานชุดนั้น, query บัญชี QA ของตัวเองได้ login rows=0, ไม่มี X server process, PID ที่ lock อ้างถึงไม่มีอยู่จริง, socket ทั้ง filesystem/abstract ต่อไม่ได้ และ `/tmp` ไม่ได้ bind/share จาก host หากไม่ครบให้หยุด ห้ามลบ lock ของจอที่ใช้งานอยู่ คู่มือเดิม `dsl_recover_stage_display.py` hardcode **legacy container** จึงห้ามรันทั้งไฟล์เพื่อแก้ NPC

ตัว guard ต่อไปนี้ทำงาน **ภายใน NPC container เท่านั้น** และลบได้สอง runtime files ที่กำหนดไว้ ไม่มี recursive delete:

```powershell
$dslXGuard = @'
import pathlib, socket, stat, json
paths = [pathlib.Path('/tmp/.X99-lock'), pathlib.Path('/tmp/.X11-unix/X99')]
def xservers():
    found = []
    for p in pathlib.Path('/proc').glob('[0-9]*/comm'):
        try:
            if p.read_text().strip() in {'Xvfb','Xorg','Xwayland','X'}:
                found.append(p.parent.name)
        except OSError:
            pass
    return found
def connected(address):
    s = socket.socket(socket.AF_UNIX); s.settimeout(.5)
    try:
        s.connect(address); return True
    except OSError:
        return False
    finally:
        s.close()
assert not xservers(), 'active_x_server'
assert not connected('/tmp/.X11-unix/X99') and not connected(chr(0)+'/tmp/.X11-unix/X99'), 'live_display'
assert not any(p.is_symlink() for p in paths), 'symlink_refused'
pid = paths[0].read_text().strip()
assert pid.isdigit() and not pathlib.Path('/proc/'+pid).exists(), 'lock_owner_exists'
snapshot = [p.lstat() for p in paths]
assert stat.S_ISREG(snapshot[0].st_mode) and stat.S_ISSOCK(snapshot[1].st_mode)
assert not xservers() and not pathlib.Path('/proc/'+pid).exists()
for p, old in zip(paths, snapshot):
    now = p.lstat()
    assert (now.st_dev,now.st_ino)==(old.st_dev,old.st_ino), 'file_changed'
    p.unlink()
print(json.dumps({'removedOnly':[str(p) for p in paths]}))
'@
$dslXGuard | & ssh @dslSshArgs 'docker exec -i dsl-origin-npc-qa-20261024 python3 -'
if ($LASTEXITCODE -ne 0) { throw 'Display guard failed; do not continue' }
& ssh @dslSshArgs 'docker exec -d dsl-origin-npc-qa-20261024 Xvfb :99 -screen 0 1024x768x16 -nolisten tcp'
```

ตรวจ Xvfb PID และ Unix socket ต่อได้ก่อนเริ่ม distribute/agent/map1 ตามลำดับ ใช้ flags จาก **NPC start.sh ปัจจุบัน**; helper legacy เก่าใช้ 24-bit แต่ NPC นี้ใช้ 16-bit อย่าคัดลอกค่าจากอีกชุดโดยไม่ตรวจ source หาก flags เปลี่ยน ให้ยืนยันเวอร์ชันและขอบเขตกับ Root ก่อน

```powershell
$dslXCheck = @'
import pathlib, socket, json
pids = []
for p in pathlib.Path('/proc').glob('[0-9]*/comm'):
    try:
        if p.read_text().strip() == 'Xvfb': pids.append(int(p.parent.name))
    except OSError:
        pass
s = socket.socket(socket.AF_UNIX); s.settimeout(1)
try:
    s.connect('/tmp/.X11-unix/X99'); ready = True
except OSError:
    ready = False
finally:
    s.close()
print(json.dumps({'xvfbPIDs':pids,'displaySocketConnects':ready}))
raise SystemExit(0 if pids and ready else 2)
'@
$dslXCheck | & ssh @dslSshArgs 'docker exec -i dsl-origin-npc-qa-20261024 python3 -'
if ($LASTEXITCODE -ne 0) { throw 'Xvfb not ready; stop before native starts' }
& ssh @dslSshArgs 'docker exec dsl-origin-npc-qa-20261024 supervisorctl -c /stage/supervisord.conf start distribute'
if ($LASTEXITCODE -ne 0) { throw 'distribute start failed' }
& ssh @dslSshArgs 'docker exec dsl-origin-npc-qa-20261024 supervisorctl -c /stage/supervisord.conf start agent'
if ($LASTEXITCODE -ne 0) { throw 'agent start failed' }
& ssh @dslSshArgs 'docker exec dsl-origin-npc-qa-20261024 supervisorctl -c /stage/supervisord.conf start map1'
if ($LASTEXITCODE -ne 0) { throw 'map1 start failed' }
```

หยุดตรวจเมื่อคำสั่งหนึ่งล้มเหลว อย่ารันวนหรือเริ่ม map อื่นตามอัตโนมัติ เก็บ hash ของสาม EXE, supervisord.conf, start.sh และ wine_odbc.reg ก่อน/หลังเพื่อยืนยันขอบเขต ไม่แก้ Wine prefix/ODBC หรือ build/deploy เพื่อกลบปัญหาจอเสมือน

## 4. จุดตรวจว่าพร้อมระดับไหน

| Gate | วิธีตรวจ | ผ่านแล้วบอกอะไรได้ |
| --- | --- | --- |
| VM | exact VMX ใน `vmrun list` | VM เปิดแล้ว |
| Identity | SSH strict เดิม + hostname `dsl-test` | เชื่อมต่อเครื่องที่คาดไว้ได้ |
| DB | container running + query readiness เดิมแบบไม่เผย credential | engine/database พร้อมรับงานตาม query ที่ตรวจ |
| Native | hash binary + supervisor states ของชุดที่เลือก | ใช้ binary ที่ตรวจและ process ที่จำเป็นทำงาน |
| Network | TCP auth/gateway ของ profile ที่เลือก | พอร์ตเข้าถึงได้ ไม่ใช่ login สำเร็จ |
| Gameplay | Root ทำ login, map entry และ logout ตาม QA ownership ปัจจุบัน | ผ่านเฉพาะสถานการณ์ที่ทดสอบจริง |

```powershell
34400,34600 | ForEach-Object {
    [pscustomobject]@{ Host='192.168.188.135'; Port=$_;
        Open=(Test-NetConnection 192.168.188.135 -Port $_ -InformationLevel Quiet) }
}
```

NPC native binary ที่ตรวจครั้งนี้: `/home/dsl/origin-npc-qa-20261024/SWorking/MapServer.exe`, SHA-256 `67e1a403b5504caa9385b4695e8145a255fd8ea387f51f6cfa45411612630c5a` หากต่างให้รายงานค่าจริงและยืนยันเวอร์ชันกับ Root ห้าม deploy ทับเพียงเพื่อให้ hash กลับมาตรง

## จุดที่ทำให้เข้าใจผิดบ่อย

- `F:\DarkStory\start_all_servers.bat` เปิด Web/API 3000 กับ WebClient 8080 ไม่ได้เปิด VM และ native game cluster
- คู่มือ Compose เก่าใช้ 14400/14600 ขณะที่ local stage ปัจจุบันแยก 24400/24600 และ 34400/34600 ต้องอ่าน profile จริง
- `dsl_phantom_health` ที่ตรวจ 14400/14600/18001 ไม่ใช่ชุดพอร์ต NPC 34400/34600 อย่าใช้ผลนั้นตัดสิน profile NPC
- เครื่อง local ใช้ IP LAN ของ VM; ค่า 127.0.0.1 ใน supervisor อาจเป็น endpoint ภายในเครื่อง/container ไม่ใช่ server IP สำหรับ Windows client
- VM boot สำเร็จแต่ game ยังไม่เปิดเป็นไปได้จาก restart=no และ map autostart=false
- ห้ามลบ login session/OwnLogin, restore DB, เติม fixture, แก้ endpoint, restart shared MCP หรือปิด process ของผู้อื่นเพื่อทำให้ health ดูผ่าน

## บันทึกผลและการหยุดเมื่อจำเป็น

บันทึก timestamp, exact VMX, IP/hostname, strict SSH exit, container name/state/restart policy, supervisor name/state, native hash และพอร์ตที่ตรวจ เก็บเฉพาะ metadata ที่จำเป็น ไม่เก็บ DSN/password/token/connection string หรือ config/log ทั้งฉบับ ระบุ pending แยกจาก pass

การเปิดครั้งนี้ไม่เปลี่ยน config, image, binary, DB schema หรือ restart policy จึงไม่มี config rollback ที่ต้องทำ อย่าปิด VM อัตโนมัติหลังตรวจสำเร็จ เพราะเจ้าของขอให้เปิดใช้งาน หากต้องหยุดภายหลัง ให้ประสานเจ้าของงาน/ตรวจ session แล้วหยุดเฉพาะชุดที่ได้รับอนุญาต และใช้ graceful shutdown ของ exact DSL VM เท่านั้น ห้าม hard reset หรือหยุด VM โครงการอื่น

## แหล่งอ้างอิงและเหตุผลที่เลือกวิธีนี้

- [VMware Workstation Pro official guide](https://techdocs2-prod.adobecqms.net/content/dam/broadcom/techdocs/us/en/pdf/vmware/desktop-hypervisors/workstation/vmware-workstation-pro-17-0.pdf): อธิบาย `vmrun start <vmx> [gui|nogui]`; ตรวจเทียบ help ของ vmrun ที่ติดตั้งจริง version `1.17.0.25388281` ก่อนใช้ คำสั่ง exact VMX แบบ nogui เหมาะกับการเปิด VM ที่มีอยู่โดยไม่รบกวนหน้าต่างเกม
- `F:/DarkStory/_worktrees/DSL-root-content-qa-20261026/Docs/Operations/DSL_RUNBOOK.md` และ `Tools/Operations/dsl_stage.py`: target private, strict SSH และ key references ปัจจุบัน
- `Tools/Operations/dsl_npc_qa_remote.py` ใน checkout เดียวกัน: ชื่อชุด NPC และ supervisor path; มีคำสั่งเตรียมข้อมูลที่เปลี่ยนแปลงระบบด้วย จึงไม่รันทั้งสคริปต์เพื่อเปิด server
- อ่านสถานะจริงด้วย `vmrun`, strict SSH, systemd และ Docker metadata แทนการ reinstall, เปลี่ยน policy หรือสร้าง container ใหม่ เพราะรอบนี้ทรัพยากรเดิมอยู่ครบและ VM เพียงปิดอยู่
- [Docker restart policy](https://docs.docker.com/engine/containers/start-containers-automatically/): `no` ไม่เปิด container กลับให้อัตโนมัติ สอดคล้องกับ metadata ของทั้งสี่ container
- [X.Org error guidance](https://www.x.org/FAQErrorMessages/): ตรวจว่าไม่มี X server/PID ใช้งานอยู่ก่อนลบ stale lock; รอบนี้เพิ่มการตรวจ Unix socket และไฟล์ภายใน container เพื่อจำกัดการกู้คืน

## ผลการเปิดวันที่ 2026-10-26

- VM power-on: PASS, exact DSL VMX; VM ของโครงการอื่นยังทำงานอยู่
- IP/identity: PASS, `192.168.188.135`, strict existing-known-host SSH exit 0, hostname `dsl-test`
- OS services: PASS, ssh/docker active
- NPC binary hash: PASS, ตรงกับค่าที่ระบุข้างบน
- ก่อนเปิด container: ทั้ง NPC/legacy สี่ตัว exited, restart=no
- DB/game/map: PASS; เปิด NPC pair เดิม, DB ทั้งสาม ONLINE, distribute/agent/map1 RUNNING
- Display: PASS หลัง guarded cleanup; Xvfb PID 772 ใน container, Unix socket ต่อได้ ใช้ flags 1024x768x16 ตาม source เดิม
- TCP: PASS, 22/34400/34600 เปิด; legacy 24400/24600 และ progression 35400/35600 ปิดตามขอบเขต
- ขอบเขต: legacy pair ยัง exited; map อื่น 86 ตัว STOPPED; binary/config ทั้งหก hash ก่อน/หลังเหมือนเดิม; ไม่ส่ง SQL write จาก operator แต่ DB engine/native boot อาจเขียนข้อมูลตามปกติ
- บัญชี QA ของตัวเอง: SELECT login rows=0 หลังเปิด ไม่ได้ล้าง session
- Login/gameplay: ยังไม่ได้ทดสอบ ไม่มีการควบคุมหน้าต่างเกมในงานเปิด VM นี้

หลักฐาน metadata ที่ตรวจเวลา 21:10:21 Bangkok: [startup evidence](evidence/20261026-local-dsl-test-startup.json) ผลนี้เป็นสถานะ ณ เวลาที่ตรวจ ไม่รับรองสถานะตลอดไป ส่งต่อให้ Root ตรวจ client/profile/lease ใหม่ก่อน login และทดสอบระบบเกมต่อ
