#!/bin/bash
# Detect the host's private IP from the default route interface.
# Works on Linux (including WSL) and macOS.
# Returns JSON for use with OpenTofu's data "external" source.

if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: get default interface from route, then grab its IPv4 address
  iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
  ip=$(ipconfig getifaddr "$iface" 2>/dev/null)
else
  # Linux/WSL: get default interface from ip route, then grab its IPv4 address
  iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
  ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print $2; exit}')
fi

if [ -z "$ip" ]; then
  echo '{"ip":"127.0.0.1"}' >&2
  exit 1
fi

echo "{\"ip\":\"${ip}\"}"
