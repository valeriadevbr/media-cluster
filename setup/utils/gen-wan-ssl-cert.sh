#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/load-env.sh"
set +a

# Gera certificado SSL Let's Encrypt para domínios WAN
sudo certbot certonly --standalone \
  -d "$WAN_HOSTNAME" \
  -d "www.$WAN_HOSTNAME" \
  -d "plex.$WAN_HOSTNAME" \
  -d "emby.$WAN_HOSTNAME"

LE_DIR="/etc/letsencrypt/live/$WAN_HOSTNAME"
DEST_DIR="$CERTS_PATH/wan"
CRT_PATH="$DEST_DIR/cert.crt"
KEY_PATH="$DEST_DIR/cert.key"
PEM_PATH="$DEST_DIR/cert.pem"
PFX_PATH="$DEST_DIR/cert.pfx"

sudo mkdir -p "$DEST_DIR"

# Copia e converte certificados
sudo cp "$LE_DIR/fullchain.pem" "$CRT_PATH"
sudo cp "$LE_DIR/privkey.pem" "$KEY_PATH"
sudo cat "$CRT_PATH" "$KEY_PATH" >"$PEM_PATH"

# Ajusta permissões
for file in "$CRT_PATH" "$KEY_PATH" "$PEM_PATH"; do
  sudo chown "$USER" "$file" 2>/dev/null || true
  sudo chmod 600 "$file" 2>/dev/null || true
done

# Gera .pfx (sem senha)
openssl pkcs12 -export \
  -out "$PFX_PATH" \
  -inkey "$KEY_PATH" \
  -in "$CRT_PATH" \
  -certfile "$CRT_PATH" \
  -password pass:
