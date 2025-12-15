#!/bin/bash
set -e

set -a
source "$(dirname -- "$0")/.env"
set +a

BACKUP_DIR="./wireguard-macos"
WG_DIR="/etc/wireguard"

sudo mkdir -p "$WG_DIR"
sudo cp -f "$BACKUP_DIR"/*.sh "$WG_DIR/"
for conf in "$BACKUP_DIR"/*.conf; do
  if [ -f "$conf" ]; then
    conf_name=$(basename "$conf")
    envsubst <"$conf" | sudo tee "$WG_DIR/$conf_name" >/dev/null
  fi
done
sudo chown -R root:wheel "$WG_DIR"
sudo chmod 755 "$WG_DIR"
sudo find "$WG_DIR" -name "*.sh" -exec chmod +x {} \;
sudo find "$WG_DIR" -name "*.conf" -exec chmod 600 {} \;

brew install wireguard-tools wireguard-go qrencode -q
sudo wg-quick down wg0
sudo wg-quick up wg0
