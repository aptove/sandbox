#!/bin/bash
# entrypoint.sh — devops-server container init
# Starts system services before handing off to the user's command.
# Must run as root; drops to developer user is handled by the CMD if needed.
set -e

# ── DBus system bus ───────────────────────────────────────────────────────────
if [ ! -e /run/dbus/system_bus_socket ]; then
    mkdir -p /run/dbus
    dbus-daemon --system --fork 2>/dev/null || true
fi

# ── UFW firewall ──────────────────────────────────────────────────────────────
# Configure and enable UFW at runtime — iptables is unavailable during build.
# Requires --cap-add=NET_ADMIN on the host.
if command -v ufw >/dev/null 2>&1; then
    ufw --force reset >/dev/null 2>&1 || true
    ufw default deny incoming >/dev/null 2>&1 || true
    ufw default allow outgoing >/dev/null 2>&1 || true
    ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1 || true
    ufw allow 41641/udp comment 'Tailscale WireGuard' >/dev/null 2>&1 || true
    ufw --force enable >/dev/null 2>&1 || true
fi

# ── Fail2ban ──────────────────────────────────────────────────────────────────
if command -v fail2ban-server >/dev/null 2>&1; then
    mkdir -p /var/run/fail2ban
    fail2ban-server -b -s /var/run/fail2ban/fail2ban.sock \
                       -p /var/run/fail2ban/fail2ban.pid \
                       -l /var/log/fail2ban.log >/dev/null 2>&1 || true
fi

# ── Hand off ──────────────────────────────────────────────────────────────────
exec "$@"
