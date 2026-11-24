# CCDC Wazuh IDS

## 1. Debian Server Host (`dist/wazuh-server-debian.tar.gz`)

```bash
tar -xzf wazuh-server-debian.tar.gz
sudo bash scripts/server/install-wazuh-server-debian.sh
```

Dashboard: `https://<DEBIAN_SERVER_IP>`

## 2. Linux Endpoints (`dist/wazuh-agent-linux.tar.gz`)

```bash
tar -xzf wazuh-agent-linux.tar.gz
sudo bash scripts/agents/install-wazuh-agent-linux.sh <DEBIAN_SERVER_IP>
```

## 3. Windows Endpoints (`dist/wazuh-agent-windows.tar.gz`)

Elevated PowerShell:
```powershell
tar -xzf wazuh-agent-windows.tar.gz
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\agents\install-wazuh-agent-windows.ps1 -ManagerIp <DEBIAN_SERVER_IP> -InstallSysmon
```
