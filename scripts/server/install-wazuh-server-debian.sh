#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

WAZUH_VER="${1:-4.9}"

require_root

log_step "Installing prerequisites"
apt-get update -qq
apt-get install -y -qq curl gnupg apt-transport-https

log_step "Installing Wazuh ${WAZUH_VER} All-in-One (Indexer, Manager, Dashboard)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -sO --output-dir "$TMP_DIR" "https://packages.wazuh.com/${WAZUH_VER}/wazuh-install.sh"
if ! apt-cache show software-properties-common >/dev/null 2>&1; then
    sed -i 's/software-properties-common//g' "${TMP_DIR}/wazuh-install.sh"
fi
bash "${TMP_DIR}/wazuh-install.sh" -a -o -i

log_step "Deploying CCDC custom rules"
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

log_step "Validating Wazuh manager configuration & rules"
/var/ossec/bin/wazuh-analysisd -t || die "wazuh-analysisd config/rule test failed!"

ensure_service_running wazuh-manager
ensure_service_running wazuh-indexer
ensure_service_running wazuh-dashboard

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    log_step "Opening Wazuh ports in UFW"
    ufw allow 1514/tcp >/dev/null
    ufw allow 1515/tcp >/dev/null
    ufw allow 443/tcp >/dev/null
fi

SERVER_IP="$(hostname -I | awk '{print $1}')"
log_ok "Wazuh Server ready on ${SERVER_IP} (Dashboard: https://${SERVER_IP})"
