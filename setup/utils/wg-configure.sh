#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
. "$(dirname -- "$0")/../includes/pkg-utils.sh"
set +a

BACKUP_DIR="$(dirname -- "$0")/../wireguard-macos"
WG_DIR="/etc/wireguard"

if ! command -v envsubst &>/dev/null; then
  echo "Instalando Gettext (envsubst)..."
  install_sys_pkg "gettext"
fi

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

if [ "$OS" = "Darwin" ]; then
  sudo chown -R root:wheel "$WG_DIR"
else
  sudo chown -R root:root "$WG_DIR"
fi

sudo chmod 755 "$WG_DIR"
sudo find "$WG_DIR" -name "*.sh" -exec chmod 755 {} \;
sudo find "$WG_DIR" -name "*.conf" -exec chmod 600 {} \;

if [ "$OS" = "Darwin" ]; then
  install_sys_pkg "wireguard-go"
else
  install_sys_pkg "wireguard"
fi
install_sys_pkg "wireguard-tools"
install_sys_pkg "qrencode"
