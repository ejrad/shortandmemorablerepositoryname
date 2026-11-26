# CCDC Live Triage Dashboard Notes

For general Wazuh UI navigation, column setup, and DQL search filters, see [WAZUH_NOTES.md](WAZUH_NOTES.md).

## 1. Import the Dashboard
1. Open Wazuh Dashboard (`https://<WAZUH_SERVER_IP>`).
2. Click **`☰` (top-left) -> Dashboard management -> Saved objects -> Import**.
3. Upload `wazuh/dashboards/ccdc-triage-dashboard.ndjson`.
4. Leave **Create new objects with random IDs** unchecked (or select **Overwrite** if re-importing).
5. If prompted for missing index pattern, select **`wazuh-alerts-*`**.
6. Open **`☰ -> Explore -> Dashboards -> CCDC Live Triage Dashboard`**.
   * Defaults to **Last 15 minutes** with **10s auto-refresh** enabled.

## 2. How to Use the 9 Panels During Competition

| Panel | What It Shows | Action to Take |
| :--- | :--- | :--- |
| **CCDC Alerts by Host Over Time** | `rule.level >= 7` per `agent.name` (1m buckets) | Spot which scored box is actively getting hit; click a host bar to filter the entire dashboard to that box. |
| **CCDC Top Attacking Source IPs** | Top 10 `data.srcip` on `rule.level >= 7` (excludes `?`) | Grab the attacker IP (`+` filter to inspect, or block at Palo Alto / host firewall). |
| **CCDC Persistence, Webshells & Rootkits** | `persistence`, `webshell`, `rootkit`, `credential_access` | **Highest priority:** check `syscheck.path` / `rule.description` and remove planted cron/SSH keys/webshells/SUIDs immediately. |
| **CCDC Active Brute Force & Recon** | SSH (`102002`), portscan (`102019`), FTP (`102024`), Mail (`102026`), Cockpit (`102028`), Windows RDP/SMB (`101009`) | Identify credential-stuffing or scanning IPs before they succeed. |
| **CCDC MITRE ATT&CK Techniques (IR)** | `rule.mitre.id` + `rule.description` (`rule.level >= 7`) | Copy-paste exact `Txxxx` technique IDs into Incident Reports. |
| **CCDC Targeted / Used Accounts (IR)** | `data.dstuser` + `agent.name` (`rule.level >= 7`) | Identify compromised/targeted accounts for password resets & IRs. |
| **CCDC Targeted / Outbound Ports** | `data.dstport` + `agent.name` + `data.srcip` (`data.dstport:*`) | Spot scanned ports and outbound C2 ports for firewall rules & IRs. |
| **CCDC Suspicious Binaries & Processes (IR)** | `data.audit.exe` / `data.win.eventdata.image` (`rule.groups:ccdc_high`) | Grab exact binary/payload paths for containment & IR evidence. |
| **CCDC Live High-Severity Feed** | Full-width live stream (`rule.groups:ccdc_high OR rule.level>=10`) | Triage alert-by-alert; click **`>`** on any row to inspect `full_log`, `data.audit.exe`, `syscheck.path`, or `data.win.eventdata.commandLine`. |

## 3. Fast Triage Workflow (5-Second Loop)
1. **Filter by host:** Click any `agent.name` in **Alerts by Host** (or add `agent.name:"<HOST>"` in the top bar) when an inject/outage hits that box.
2. **Exclude noisy benign IP:** Hover over a legitimate scoring-engine IP in **Top Attacking Source IPs** and click **`-`** (Filter out).
3. **Clear filters:** Click the filter pill **x** at the top to return to the fleet-wide view.

## 4. Incident Report (IR) Workflow
1. **Freeze the window:** Pause `10s` auto-refresh, or drag-select the attack spike in **CCDC Alerts by Host Over Time** to lock the time range.
2. **Pivot to the incident:** Click **`+`** on the attacker IP in **CCDC Top Attacking Source IPs** (and/or the affected `agent.name`). Every panel updates to just that incident.
3. **Pull IR fields directly from the panels:**
   * **Timeline:** Earliest & latest timestamps in **CCDC Live High-Severity Feed**.
   * **MITRE IDs:** Copy from **CCDC MITRE ATT&CK Techniques (IR)**.
   * **Accounts:** Copy from **CCDC Targeted / Used Accounts (IR)**.
   * **Ports:** Copy from **CCDC Targeted / Outbound Ports**.
   * **IOCs / Evidence:** Copy binary & file paths from **CCDC Suspicious Binaries & Processes (IR)** and **CCDC Persistence, Webshells & Rootkits** (expand **`>`** on a row in the feed for `full_log` / `commandLine`).
4. **Resume:** Remove the filter pills at the top and unpause auto-refresh.
