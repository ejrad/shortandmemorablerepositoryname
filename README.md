# CCDC Wazuh IDS

## Ports
- `51514/tcp` — Agent events (custom, replaces `1514`)
- `51515/tcp` — Agent enrollment (custom, replaces `1515`)
- `443/tcp` — Wazuh Dashboard

*(Linux installers enable `ufw logging on` or `firewalld --set-log-denied=all` if active; for raw `iptables`, log drops with `--log-prefix "[UFW BLOCK] "` to trigger port-scan rule `102017`.)*

## 1. Debian Server Host (`dist/wazuh-server-debian.tar.gz`)

```bash
curl -fSLO https://raw.githubusercontent.com/ejrad/shortandmemorablerepositoryname/main/dist/wazuh-server-debian.tar.gz
tar -xzf wazuh-server-debian.tar.gz
sudo bash scripts/server/install-wazuh-server-debian.sh
```

Dashboard: `https://<DEBIAN_SERVER_IP>`

## 2. Linux Endpoints (`dist/wazuh-agent-linux.tar.gz`)

```bash
curl -fSLO https://raw.githubusercontent.com/ejrad/shortandmemorablerepositoryname/main/dist/wazuh-agent-linux.tar.gz
tar -xzf wazuh-agent-linux.tar.gz
sudo bash scripts/agents/install-wazuh-agent-linux.sh <DEBIAN_SERVER_IP>
```

## 3. Windows Endpoints (`dist/wazuh-agent-windows.tar.gz`)

Elevated PowerShell:
```powershell
curl.exe -fSLO https://raw.githubusercontent.com/ejrad/shortandmemorablerepositoryname/main/dist/wazuh-agent-windows.tar.gz
tar -xzf wazuh-agent-windows.tar.gz
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\agents\install-wazuh-agent-windows.ps1 -ManagerIp <DEBIAN_SERVER_IP> -InstallSysmon
```

## 4. Useful Commands (Debian Server)

Find generated dashboard `admin` password:
```bash
sudo tar -O -xf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt | grep -A 2 "'admin'"
```

Change dashboard `admin` password (requires upper, lower, number, and a symbol from `.*+?-`):
```bash
curl -sO https://packages.wazuh.com/4.14/wazuh-passwords-tool.sh && sudo bash wazuh-passwords-tool.sh -u admin -p '!XXXXXXXXXXXXXXXXXX!'
```

Check server services & connected agents:
```bash
sudo systemctl status wazuh-manager wazuh-indexer wazuh-dashboard --no-pager
sudo /var/ossec/bin/agent_control -l
```

Tail live alerts:
```bash
sudo tail -f /var/ossec/logs/alerts/alerts.log
```

Test rules/config after editing:
```bash
sudo /var/ossec/bin/wazuh-analysisd -t && sudo systemctl restart wazuh-manager
```
