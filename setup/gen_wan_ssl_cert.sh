#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/includes/setup_vars.sh"

# # Gera certificado SSL usando Let's Encrypt para o domínio definido em $WAN_HOST
sudo certbot certonly \
  --standalone \
  -d "$WAN_HOST" \
  -d "www.$WAN_HOST" \
  -d "plex.$WAN_HOST" \
  -d "emby.$WAN_HOST"

# Caminhos dos arquivos gerados pelo Let's Encrypt
LE_DIR="/etc/letsencrypt/live/$WAN_HOST"
DEST_DIR="$SSL_CONFIG_DIR/wan"
FULLCHAIN="$LE_DIR/fullchain.pem"
PRIVKEY="$LE_DIR/privkey.pem"

mkdir -p "$DEST_DIR"

# Converter para .crt e .key
sudo cp "$FULLCHAIN" "$DEST_DIR/$WAN_HOST.crt"
sudo cp "$PRIVKEY" "$DEST_DIR/$WAN_HOST.key"
sudo chown $USER "$DEST_DIR/$WAN_HOST.crt" "$DEST_DIR/$WAN_HOST.key"
sudo chmod 600 "$DEST_DIR/$WAN_HOST.crt" "$DEST_DIR/$WAN_HOST.key"

# Converter para .pfx (sem senha)
openssl pkcs12 -export \
  -out "$DEST_DIR/$WAN_HOST.pfx" \
  -inkey "$DEST_DIR/$WAN_HOST.key" \
  -in "$DEST_DIR/$WAN_HOST.crt" \
  -certfile "$DEST_DIR/$WAN_HOST.crt" \
  -password pass:
