#!/usr/bin/env bash

log_step() { printf '\n==> %s\n' "$1"; }
log_ok()   { printf '[OK] %s\n' "$1"; }
log_warn() { printf '[WARN] %s\n' "$1" >&2; }
die()      { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

require_root() {
    [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root (sudo)."
}

check_tcp_reachable() {
    local host="$1" port="$2"
    if timeout 5 bash -c "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null; then
        log_ok "Reachable: ${host}:${port}"
        return 0
    else
        log_warn "Cannot reach ${host}:${port} (firewall, route, or service down)."
        return 1
    fi
}

detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    else
        die "Unsupported package manager (expected apt-get, dnf, or yum)."
    fi
}

ensure_service_running() {
    local svc="$1"
    systemctl daemon-reload
    systemctl enable --now "$svc"
    sleep 3
    if systemctl is-active --quiet "$svc"; then
        log_ok "Service $svc is running."
    else
        journalctl -u "$svc" -n 25 --no-pager >&2 || true
        die "Service $svc failed to start."
    fi
}
