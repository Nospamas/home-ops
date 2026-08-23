#!/bin/sh
set -eu

target=/config/.storage/http

# HA owns it after first boot.
if [ -e "$target" ]; then
  exit 0
fi

mkdir -p /config/.storage
cat /seed/http.json > "$target"
