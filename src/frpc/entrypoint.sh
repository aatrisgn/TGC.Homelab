#!/bin/sh
set -eu

missing=""
for var in FRPC_SERVER_ADDR FRPC_SERVER_PORT FRPC_AUTH_TOKEN FRPC_LOCAL_IP FRPC_HTTP_LOCAL_PORT FRPC_HTTPS_LOCAL_PORT; do
  eval "value=\${$var:-}"
  if [ -z "$value" ]; then
    missing="$missing $var"
  fi
done

if [ -n "$missing" ]; then
  echo "Missing required environment variables:$missing" >&2
  exit 1
fi

exec /usr/local/bin/frpc -c /etc/frp/frpc.toml
