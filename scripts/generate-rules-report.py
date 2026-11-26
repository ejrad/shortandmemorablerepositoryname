#!/usr/bin/env python3
import html
import json
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RULES_DIR = ROOT / "wazuh" / "rules"
REPORTS_DIR = ROOT / "reports"
TMPL_PATH = REPORTS_DIR / "template" / "rules-report.html.tmpl"
STATUS_PATH = REPORTS_DIR / "rule-status.json"

BROWSER_CANDIDATES = [
    shutil.which("chrome"),
    shutil.which("msedge"),
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
]


def find_browser() -> str:
    for c in BROWSER_CANDIDATES:
        if c and Path(c).exists():
            return str(c)
    raise FileNotFoundError("Chrome or Edge executable not found for PDF export.")


def parse_rules(xml_path: Path, tested: set[int], new_ids: set[int]) -> list[dict]:
    root = ET.fromstring(f"<wrap>{xml_path.read_text(encoding='utf-8')}</wrap>")
    rows = []
    for r in root.iter("rule"):
        rid = int(r.get("id"))
        lvl = int(r.get("level", "0"))
        desc = (r.findtext("description") or "").strip()
        mitre = [m.text.strip() for m in r.findall("mitre/id") if m.text]
        groups = [g.strip() for g in (r.findtext("group") or "").split(",") if g.strip()]
        status = "TESTED" if rid in tested else ("NEW" if rid in new_ids else "UNTESTED")
        rows.append({"id": rid, "level": lvl, "desc": desc, "mitre": mitre, "groups": groups, "status": status})
    return rows


def lvl_badge(lvl: int) -> str:
    cls = "lvl-crit" if lvl >= 12 else ("lvl-high" if lvl >= 8 else ("lvl-med" if lvl >= 4 else "lvl-low"))
    return f'<span class="badge {cls}">Lvl {lvl}</span>'


def status_badge(st: str) -> str:
    cls = {"TESTED": "st-tested", "NEW": "st-new"}.get(st, "st-untested")
    return f'<span class="badge {cls}">{st}</span>'


def render_section(title: str, rows: list[dict]) -> str:
    trs = []
    for r in rows:
        mitre_html = " ".join(f'<span class="tag">{html.escape(m)}</span>' for m in r["mitre"]) or '<span class="muted">—</span>'
        grp_html = ", ".join(html.escape(g) for g in r["groups"]) or "—"
        trs.append(
            f'<tr><td class="mono">{r["id"]}</td>'
            f'<td>{lvl_badge(r["level"])}</td>'
            f'<td>{status_badge(r["status"])}</td>'
            f'<td><strong>{html.escape(r["desc"])}</strong><div class="groups">{grp_html}</div></td>'
            f'<td>{mitre_html}</td></tr>'
        )
    return (
        f'<section><h2>{html.escape(title)} <span class="count">({len(rows)} rules)</span></h2>'
        f'<table><thead><tr>'
        f'<th style="width:68px">Rule ID</th><th style="width:72px">Severity</th>'
        f'<th style="width:88px">Status</th><th>Description &amp; Groups</th>'
        f'<th style="width:120px">MITRE ATT&amp;CK</th></tr></thead>'
        f'<tbody>{"".join(trs)}</tbody></table></section>'
    )


def main() -> None:
    status_data = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
    tested = set(status_data.get("tested", []))
    new_ids = set(status_data.get("new", []))

    rule_files = sorted(RULES_DIR.glob("*.xml"))
    all_rows, sections = [], []
    for path in rule_files:
        rows = parse_rules(path, tested, new_ids)
        all_rows.extend(rows)
        sections.append(render_section(path.name, rows))

    total = len(all_rows)
    tested_cnt = sum(1 for r in all_rows if r["status"] == "TESTED")
    new_cnt = sum(1 for r in all_rows if r["status"] == "NEW")
    untested_cnt = sum(1 for r in all_rows if r["status"] == "UNTESTED")

    kpis = (
        f'<div class="kpis">'
        f'<div class="kpi"><div class="num">{total}</div><div class="lbl">Total Rules</div></div>'
        f'<div class="kpi tested"><div class="num">{tested_cnt}</div><div class="lbl">Tested</div></div>'
        f'<div class="kpi new"><div class="num">{new_cnt}</div><div class="lbl">New</div></div>'
        f'<div class="kpi untested"><div class="num">{untested_cnt}</div><div class="lbl">Untested</div></div>'
        f'</div>'
    )
    legend = (
        '<div class="legend"><strong>Status Legend:</strong> '
        '<span class="badge st-tested">TESTED</span> Verified live. &nbsp; '
        '<span class="badge st-new">NEW</span> Added since last test. &nbsp; '
        '<span class="badge st-untested">UNTESTED</span> Pending live test.</div>'
    )

    now = datetime.now()
    html_out = (
        TMPL_PATH.read_text(encoding="utf-8")
        .replace("{{TITLE}}", "CCDC Wazuh 4.14 Detection Rules Report")
        .replace("{{SUBTITLE}}", f"Generated {now.strftime('%Y-%m-%d %I:%M %p')} &bull; {total} Custom Rules")
        .replace("{{KPI_CARDS}}", kpis)
        .replace("{{LEGEND}}", legend)
        .replace("{{SECTIONS}}", "".join(sections))
    )

    out_pdf = REPORTS_DIR / f"wazuh-rules-report-{now.strftime('%Y-%m-%d_%H-%M')}.pdf"
    browser = find_browser()
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as tmp:
        tmp.write(html_out)
        tmp_path = Path(tmp.name)
    try:
        subprocess.run([browser, "--headless", "--disable-gpu", "--no-pdf-header-footer", f"--print-to-pdf={out_pdf}", tmp_path.as_uri()], check=True)
    finally:
        tmp_path.unlink(missing_ok=True)
    print(f"Generated {out_pdf.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
