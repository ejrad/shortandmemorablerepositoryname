#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

MANAGER_IP="${1:-}"
AGENT_GROUP="${2:-linux}"
WAZUH_VER="${3:-4.14}"

[[ -n "$MANAGER_IP" ]] || die "Usage: sudo bash $0 <MANAGER_IP> [AGENT_GROUP] [WAZUH_VERSION]"
require_root

log_step "Checking connectivity to Wazuh Manager (${MANAGER_IP})"
check_tcp_reachable "$MANAGER_IP" "$WAZUH_EVENTS_PORT" || true
check_tcp_reachable "$MANAGER_IP" "$WAZUH_ENROLL_PORT" || true

PKG_MGR="$(detect_pkg_manager)"
log_step "Installing auditd and Wazuh ${WAZUH_VER} agent (${PKG_MGR})"

if [[ "$PKG_MGR" == "apt" ]]; then
    apt-get update -qq
    apt-get install -y -qq curl gnupg apt-transport-https lsb-release auditd audispd-plugins
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
    chmod 644 /usr/share/keyrings/wazuh.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
    apt-get update -qq
    WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_GROUP="$AGENT_GROUP" apt-get install -y wazuh-agent
else
    "$PKG_MGR" install -y audit
    rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
    cat > /etc/yum.repos.d/wazuh.repo <<EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF
    WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_GROUP="$AGENT_GROUP" "$PKG_MGR" install -y wazuh-agent
fi

AUDIT_SRC="${REPO_ROOT}/wazuh/agent-configs/ccdc-audit.rules"
if [[ -f "$AUDIT_SRC" ]]; then
    log_step "Deploying CCDC auditd rules"
    install -d -m 0750 /etc/audit/rules.d
    install -m 0640 "$AUDIT_SRC" /etc/audit/rules.d/ccdc.rules
    augenrules --load >/dev/null 2>&1 || auditctl -R /etc/audit/rules.d/ccdc.rules >/dev/null 2>&1 || true
    ensure_service_running auditd
fi

log_step "Configuring agent ports and starting wazuh-agent"
configure_wazuh_ports /var/ossec/etc/ossec.conf "$WAZUH_EVENTS_PORT" "$WAZUH_ENROLL_PORT"
ensure_service_running wazuh-agent
log_ok "Linux endpoint enrolled to ${MANAGER_IP} (group: ${AGENT_GROUP})."
