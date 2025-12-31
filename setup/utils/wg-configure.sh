#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
if [ "$OS" = "Darwin" ]; then
  HOMEBREW_NO_AUTO_UPDATE=1
  HOMEBREW_NO_ENV_HINTS=1
fi
set +a

BACKUP_DIR="$(dirname -- "$0")/../wireguard-macos"
WG_DIR="/etc/wireguard"

sudo mkdir -p "$WG_DIR"
for script in "$BACKUP_DIR"/*.sh; do
  if [ -f "$script" ]; then
    script_name=$(basename "$script")
    envsubst '${WG_SUBNET} ${WG_SERVER_IP} ${DOCKER_HOST_IP} ${DOCKER_HOST_SUBNET}' <"$script" | sudo tee "$WG_DIR/$script_name" >/dev/null
  fi
done
for conf in "$BACKUP_DIR"/*.conf; do
  if [ -f "$conf" ]; then
    conf_name=$(basename "$conf")
    envsubst <"$conf" | sudo tee "$WG_DIR/$conf_name" >/dev/null
  fi
done
sudo chown -R root:wheel "$WG_DIR"
sudo chmod 755 "$WG_DIR"
sudo find "$WG_DIR" -name "*.sh" -exec chmod 755 {} \;
sudo find "$WG_DIR" -name "*.conf" -exec chmod 600 {} \;

if [ "$OS" = "Darwin" ]; then
  brew install wireguard-tools wireguard-go qrencode -q
else
  sudo apt-get install wireguard wireguard-tools qrencode
fi

# sudo wg-quick down wg0
# sudo wg-quick up wg0
