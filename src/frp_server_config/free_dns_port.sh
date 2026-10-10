#!/usr/bin/env bash
# Frees port 53 on the frps VPS so frps can expose the CoreDNS nameserver.
# Ubuntu's systemd-resolved stub listener holds 127.0.0.53:53 by default. Run as root on the VPS.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo $0)" >&2
  exit 1
fi

resolved_conf=/etc/systemd/resolved.conf

# Disable the stub listener (idempotent: replaces a commented or existing setting, appends otherwise)
if grep -qE '^#?DNSStubListener=' "$resolved_conf"; then
  sed -i -E 's/^#?DNSStubListener=.*/DNSStubListener=no/' "$resolved_conf"
else
  echo 'DNSStubListener=no' >> "$resolved_conf"
fi

# Point resolv.conf at the upstream resolvers instead of the disabled stub
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

systemctl restart systemd-resolved

if ss -lnup 'sport = :53' | grep -q systemd-resolve || ss -lntp 'sport = :53' | grep -q systemd-resolve; then
  echo "systemd-resolved is still listening on port 53" >&2
  exit 1
fi

echo "Port 53 is free. Restart frps (or let frpc reconnect) so the dns-udp/dns-tcp proxies can bind it."
