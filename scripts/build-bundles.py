#!/usr/bin/env python3
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
DIST.mkdir(exist_ok=True)

BUNDLES = {
    "wazuh-server-debian.tar.gz": [
        "scripts/server/install-wazuh-server-debian.sh",
        "scripts/server/check-wazuh-rule-ids.py",
        "scripts/lib/common.sh",
        "wazuh/rules/local_rules.xml",
        "wazuh/rules/ccdc_windows_rules.xml",
        "wazuh/rules/ccdc_linux_rules.xml",
        "wazuh/agent-configs/windows-agent.conf",
        "wazuh/agent-configs/linux-agent.conf",
        "wazuh/agent-configs/ccdc-audit.rules",
    ],
    "wazuh-agent-linux.tar.gz": [
        "scripts/agents/install-wazuh-agent-linux.sh",
        "scripts/lib/common.sh",
        "wazuh/agent-configs/ccdc-audit.rules",
    ],
    "wazuh-agent-windows.tar.gz": [
        "scripts/agents/install-wazuh-agent-windows.ps1",
        "scripts/lib/Common.psm1",
        "wazuh/agent-configs/sysmonconfig.xml",
    ],
}

for name, files in BUNDLES.items():
    out = DIST / name
    with tarfile.open(out, "w:gz") as tf:
        for rel in files:
            src = ROOT / rel
            if not src.is_file():
                raise FileNotFoundError(f"Missing {src}")
            info = tf.gettarinfo(src, arcname=rel)
            if rel.endswith(".sh"):
                info.mode = 0o755
            with src.open("rb") as f:
                tf.addfile(info, f)
    print(f"Built {out.relative_to(ROOT)} ({len(files)} files)")
