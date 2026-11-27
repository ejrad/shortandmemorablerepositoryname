# Windows Test Suite

## Automated Run (Recommended)
Run from the extracted `wazuh-agent-windows.tar.gz` bundle in an **elevated PowerShell** prompt:
```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\test-windows-detections.ps1 -KaliIp <KALI_IP>
```
- Runs safe local detection tests (`101001`–`101003`, `101012`, `101015`–`101017`, `101019`, `101023`, `101024`, `101028`, `101030`, `101032`) and cleans up all temporary files, registry values, tasks, and test users.
- Prints the optional **Kali** `hydra` command for `101004` / `101005` (Windows brute force).

---

## Manual / Additional Tests (Outside Script)
- **Defender Threat / Tamper (`101006`, `101007`):** Trigger EICAR test string or toggle Real-Time Protection briefly and re-enable.
- **Credential Dumping (`101008`, `101014`, `101025`):** Run `procdump` / `comsvcs.dll MiniDump` against a test process or `lsass.exe` in a lab VM.
- **RDP Logon / Reconnect (`101009`, `101010`):** Connect/disconnect via RDP (`xfreerdp` from Kali).
- **Event Log Cleared (`101011`):** `wevtutil cl Application` (note: clears Application log).
- **Process Injection / Hollowing / Unmanaged CLR (`101013`, `101018`, `101022`):** Test with authorized C2/injection lab tools.
- **WMI Persistence & Named Pipes (`101020`, `101021`):** Create/delete a test WMI `__EventFilter` or `psexec` from Kali.
- **AD Attacks (`101026`, `101027`, `101029`, `101031`):** Kerberoast (`GetUserSPNs.py`), DCSync (`secretsdump.py`), `Enter-PSSession -ComputerName`, or `netsh advfirewall set allprofiles state off` (re-enable immediately).
