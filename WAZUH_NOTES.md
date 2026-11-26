# Wazuh Dashboard Notesheet (CCDC)

## 1. Live Alert Triage (Main Screen)
1. Click **`☰` (top-left) -> Threat intelligence -> Threat Hunting -> Events**.
2. Click the **time picker (top-right)** -> set **Last 15 minutes** (or **Last 1 hour**) -> click **Refresh every `5` or `10` seconds -> Start**.
3. **Recommended Columns** (click **Columns**): `data.srcip`, `syscheck.path`, `data.audit.exe`, `data.audit.execve.a1`, `data.dstuser`, `data.dstport`, `data.win.eventdata.image`, `data.win.eventdata.commandLine`.
4. **12-hr time-only format**: `☰ -> Dashboard management -> Advanced settings -> dateFormat` -> `hh:mm:ss A` -> **Save** & refresh.
5. Expand any row (`>` / magnifying glass) and switch to the **JSON** or **Table** tab to see full process paths, parent processes, command lines, and IPs.

## 2. High-Value Search Filters (DQL Bar)
Paste any of these into the top search bar:

| Goal | Filter |
| :--- | :--- |
| **All CCDC High-Priority Alerts** | `rule.groups:ccdc_high` |
| **All Critical Alerts (Level 12+)** | `rule.level>=12` |
| **Single Host** | `agent.name:"<HOSTNAME>"` |
| **PowerShell / ScriptBlocks** | `rule.groups:powershell` |
| **Process Injection / LSASS / Hollowing** | `rule.id:(101013 OR 101014 OR 101022 OR 101024 OR 101025)` |
| **C2 Outbound / Named Pipes** | `rule.id:(101015 OR 101021 OR 102009)` |
| **Brute Force / Logins (Win + Linux)** | `rule.id:(101005 OR 101009 OR 101010 OR 102002 OR 102003 OR 102004)` |
| **Persistence (Services/Tasks/Run/Cron/SSH)** | `rule.groups:persistence` |
| **Webshells & Webroot Changes** | `rule.groups:webshell` |
| **Credential Access (Kerberoast/DCSync/Shadow)** | `rule.groups:credential_access` |
| **Lateral Movement (WinRM/WMI/PsExec)** | `rule.groups:lateral_movement` |

## 3. Key Fields to Check Inside an Alert
- **Windows Process / Parent / CLI**:
  - `data.win.eventdata.image` (executable path)
  - `data.win.eventdata.parentImage` (parent process)
  - `data.win.eventdata.commandLine` / `parentCommandLine`
  - `data.win.eventdata.destinationIp` & `destinationPort` (Sysmon 3)
  - `data.win.eventdata.sourceImage` -> `targetImage` (Sysmon 8/10)
- **Linux Audit / Auth**:
  - `data.audit.exe`, `data.audit.comm`, `data.audit.ppid`
  - `data.srcip`, `data.dstuser`
- **File Changes (FIM)**:
  - `syscheck.path`, `syscheck.event` (`added`/`modified`/`deleted`), `syscheck.sha256_after`

## 4. Endpoint Views
Click **Endpoints** (or **Agents**) -> select a host:
- **Inventory Data**: Live snapshot of **Processes**, **Open Ports**, **Installed Packages**, **Network Interfaces**, and **Hotfixes** (updates every `3m`).
- **File Integrity Monitoring**: Browse all modified/added files in webroots, `/etc`, and Startup folders.
- **Configuration Assessment (SCA)**: CIS hardening pass/fail checks per host.
- **MITRE ATT&CK**: Group alerts by tactic/technique (`T1055`, `T1003`, `T1059`, etc.).
