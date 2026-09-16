#!/bin/sh
# Join the tailnet before handing control to Paperclip's agent shim, so the
# MCP gateway at the tailnet hostname resolves from inside the sandbox.
#
# Runs as uid 1000, not root. tailscaled needs /dev/net/tun + NET_ADMIN for a
# real interface; without them the only option is userspace networking, which
# exposes a proxy rather than an interface. Node's fetch ignores proxy env vars
# unless the client opts in, so the userspace path may not carry MCP traffic.
# Both modes are attempted and the chosen one is logged, so a failure to reach
# the gateway is diagnosable instead of silent.
set -e

TS_STATE_DIR="${TS_STATE_DIR:-/tmp/tailscale}"
TS_SOCKET="${TS_SOCKET:-/tmp/tailscaled.sock}"

if [ -n "$TS_AUTHKEY" ]; then
  mkdir -p "$TS_STATE_DIR"

  if [ -c /dev/net/tun ] && [ -w /dev/net/tun ]; then
    echo "[tailscale] /dev/net/tun present — starting in TUN mode"
    tailscaled \
      --state="$TS_STATE_DIR/tailscaled.state" \
      --socket="$TS_SOCKET" \
      --tun=tailscale0 >/tmp/tailscaled.log 2>&1 &
  else
    echo "[tailscale] no usable /dev/net/tun — falling back to userspace networking"
    echo "[tailscale] WARNING: MCP traffic may not traverse a proxy-only tailnet"
    tailscaled \
      --state="$TS_STATE_DIR/tailscaled.state" \
      --socket="$TS_SOCKET" \
      --tun=userspace-networking \
      --socks5-server=localhost:1055 \
      --outbound-http-proxy-listen=localhost:1055 >/tmp/tailscaled.log 2>&1 &
    ALL_PROXY="socks5://localhost:1055/"
    HTTP_PROXY="http://localhost:1055/"
    HTTPS_PROXY="http://localhost:1055/"
    NO_PROXY="localhost,127.0.0.1"
    export ALL_PROXY HTTP_PROXY HTTPS_PROXY NO_PROXY
  fi

  # Ephemeral so the node removes itself when the lease is recycled, and tagged
  # so a tailnet ACL can confine it to the Paperclip host alone.
  if tailscale --socket="$TS_SOCKET" up \
        --authkey="$TS_AUTHKEY" \
        --hostname="paperclip-sandbox-$(hostname | tr -cd 'a-zA-Z0-9-')" \
        --accept-dns=true \
        --accept-routes=false \
        --timeout=45s; then
    echo "[tailscale] joined: $(tailscale --socket="$TS_SOCKET" ip -4 2>/dev/null | head -1)"
  else
    echo "[tailscale] JOIN FAILED — Paperclip MCP tools will be unreachable"
    tail -20 /tmp/tailscaled.log 2>/dev/null || true
  fi

  # The auth key must not survive into the agent process environment.
  unset TS_AUTHKEY
else
  echo "[tailscale] TS_AUTHKEY not set — skipping tailnet join"
fi

exec /usr/bin/tini -- "$@"
