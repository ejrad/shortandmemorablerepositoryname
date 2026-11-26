#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

WAZUH_VER="${1:-4.14}"

require_root

log_step "Installing prerequisites"
apt-get update -qq
apt-get install -y -qq curl gnupg apt-transport-https auditd audispd-plugins

systemctl stop wazuh-manager wazuh-indexer wazuh-dashboard filebeat 2>/dev/null || true

log_step "Installing Wazuh ${WAZUH_VER} All-in-One (Indexer, Manager, Dashboard)"
if df -T /tmp | awk 'NR==2{exit ($2 != "tmpfs")}'; then
    export TMPDIR=/var/tmp
    TMP_DIR="$(mktemp -d -p /var/tmp)"
    systemctl mask tmp.mount >/dev/null 2>&1 || true
else
    TMP_DIR="$(mktemp -d)"
fi
trap 'rm -rf "$TMP_DIR"' EXIT
curl -sO --output-dir "$TMP_DIR" "https://packages.wazuh.com/${WAZUH_VER}/wazuh-install.sh"
if ! apt-cache show software-properties-common >/dev/null 2>&1; then
    sed -i 's/software-properties-common//g' "${TMP_DIR}/wazuh-install.sh"
fi
sed -i -E "s/\b1514\b/${WAZUH_EVENTS_PORT}/g; s/\b1515\b/${WAZUH_ENROLL_PORT}/g" "${TMP_DIR}/wazuh-install.sh"
sed -i -E "s|(systemctl start )|[[ -f /var/ossec/etc/ossec.conf ]] \&\& sed -i -E 's\|<port>1514</port>\|<port>${WAZUH_EVENTS_PORT}</port>\|g; s\|<port>1515</port>\|<port>${WAZUH_ENROLL_PORT}</port>\|g' /var/ossec/etc/ossec.conf; \1|g" "${TMP_DIR}/wazuh-install.sh"
bash "${TMP_DIR}/wazuh-install.sh" -a -o -i

log_step "Deploying CCDC custom decoders and rules"
install -d -m 0750 -o root -g wazuh /var/ossec/etc/decoders
for dec in "${REPO_ROOT}/wazuh/decoders/"*.xml; do
    install -m 0640 -o root -g wazuh "$dec" "/var/ossec/etc/decoders/$(basename "$dec")"
    log_ok "Installed decoder: $(basename "$dec")"
done
install -d -m 0750 -o root -g wazuh /var/ossec/etc/rules
for rule in "${REPO_ROOT}/wazuh/rules/"*.xml; do
    install -m 0640 -o root -g wazuh "$rule" "/var/ossec/etc/rules/$(basename "$rule")"
    log_ok "Installed rule: $(basename "$rule")"
done

log_step "Creating agent groups (windows, linux) and deploying agent.conf"
for grp in windows linux; do
    /var/ossec/bin/agent_groups -a -g "$grp" -q 2>/dev/null || true
    install -d -m 0750 -o wazuh -g wazuh "/var/ossec/etc/shared/${grp}"
    install -m 0640 -o wazuh -g wazuh \
        "${REPO_ROOT}/wazuh/agent-configs/${grp}-agent.conf" \
        "/var/ossec/etc/shared/${grp}/agent.conf"
    log_ok "Configured group '${grp}'"
done

AUDIT_SRC="${REPO_ROOT}/wazuh/agent-configs/ccdc-audit.rules"
if [[ -f "$AUDIT_SRC" ]]; then
    log_step "Deploying CCDC auditd rules on server host"
    install -d -m 0750 /etc/audit/rules.d
    install -m 0640 "$AUDIT_SRC" /etc/audit/rules.d/ccdc.rules
    augenrules --load >/dev/null 2>&1 || auditctl -R /etc/audit/rules.d/ccdc.rules >/dev/null 2>&1 || true
    ensure_service_running auditd
fi

if ! grep -q '/var/log/audit/audit.log' /var/ossec/etc/ossec.conf; then
    log_step "Applying Linux CCDC monitoring to server host ossec.conf"
    HOST_SNIPPET="$(sed '/<\/\?agent_config>/d' "${REPO_ROOT}/wazuh/agent-configs/linux-agent.conf")"
    python3 -c '
import pathlib, sys
p = pathlib.Path("/var/ossec/etc/ossec.conf")
txt = p.read_text()
idx = txt.rfind("</ossec_config>")
if idx != -1:
    p.write_text(txt[:idx] + "\n" + sys.argv[1] + "\n" + txt[idx:])
' "$HOST_SNIPPET"
fi

log_step "Configuring Wazuh manager ports (${WAZUH_EVENTS_PORT}, ${WAZUH_ENROLL_PORT})"
configure_wazuh_ports /var/ossec/etc/ossec.conf "$WAZUH_EVENTS_PORT" "$WAZUH_ENROLL_PORT"

log_step "Validating Wazuh manager configuration & rules"
/var/ossec/bin/wazuh-analysisd -t || die "wazuh-analysisd config/rule test failed!"

systemctl restart wazuh-manager
ensure_service_running wazuh-manager
ensure_service_running wazuh-indexer
ensure_service_running wazuh-dashboard

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    log_step "Opening Wazuh ports in UFW"
    ufw allow "${WAZUH_EVENTS_PORT}/tcp" >/dev/null
    ufw allow "${WAZUH_ENROLL_PORT}/tcp" >/dev/null
    ufw allow 443/tcp >/dev/null
    ufw logging on >/dev/null
fi

SERVER_IP="$(hostname -I | awk '{print $1}')"
log_ok "Wazuh Server ready on ${SERVER_IP} (Dashboard: https://${SERVER_IP})"
