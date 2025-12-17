#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/.env"
source "$(dirname -- "$0")/includes/generate_local_cert.sh"

generate_local_cert \
  "localhost" \
  "$CERTS_PATH/ca/ca.crt" \
  "$CERTS_PATH/ca/ca.key" \
  "$CERTS_PATH/lan/san/local-san.cnf" \
  "$CERTS_PATH/lan"
