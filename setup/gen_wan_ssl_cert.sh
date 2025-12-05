#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/includes/setup_vars.sh"

# # Gera certificado SSL usando Let's Encrypt para o domínio apedamo.tplinkdns.com
# sudo certbot certonly --standalone -d apedamo.tplinkdns.com

# Caminhos dos arquivos gerados pelo Let's Encrypt
LE_DIR="/etc/letsencrypt/live/apedamo.tplinkdns.com"
DEST_DIR="$SSL_CONFIG_DIR/wan"
FULLCHAIN="$LE_DIR/fullchain.pem"
PRIVKEY="$LE_DIR/privkey.pem"

mkdir -p "$DEST_DIR"

# Converter para .crt e .key
sudo cp "$FULLCHAIN" "$DEST_DIR/apedamo.tplinkdns.com.crt"
sudo cp "$PRIVKEY" "$DEST_DIR/apedamo.tplinkdns.com.key"
sudo chown $USER "$DEST_DIR/apedamo.tplinkdns.com.crt" "$DEST_DIR/apedamo.tplinkdns.com.key"
sudo chmod 600 "$DEST_DIR/apedamo.tplinkdns.com.crt" "$DEST_DIR/apedamo.tplinkdns.com.key"

# Converter para .pfx (sem senha)
openssl pkcs12 -export \
  -out "$DEST_DIR/apedamo.tplinkdns.com.pfx" \
  -inkey "$DEST_DIR/apedamo.tplinkdns.com.key" \
  -in "$DEST_DIR/apedamo.tplinkdns.com.crt" \
  -certfile "$DEST_DIR/apedamo.tplinkdns.com.crt" \
  -password pass:
