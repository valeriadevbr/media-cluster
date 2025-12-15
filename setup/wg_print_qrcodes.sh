#!/bin/bash
set -e

CONF_DIR="./wireguard-macos"

for conf in "$CONF_DIR"/peer_*.conf; do
  if [ -f "$conf" ]; then
    echo "Arquivo: $conf"
    qrencode "$conf" -t ASCII -o -
    echo ""
  fi
done
