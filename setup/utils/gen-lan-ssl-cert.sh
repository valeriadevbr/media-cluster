#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/../.env"
source "${SETUP_PATH}/includes/generate-local-cert.sh"

generate_local_cert \
  "media.lan" \
  "$CERTS_PATH/ca/ca.crt" \
  "$CERTS_PATH/ca/ca.key" \
  "$CERTS_PATH/lan/san/local-san.cnf" \
  "$CERTS_PATH/lan"
