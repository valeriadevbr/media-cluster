#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/includes/setup_vars.sh"
source "$(dirname -- "$0")/includes/generate_local_cert.sh"

generate_local_cert \
  "localhost" \
  "$SSL_CONFIG_DIR/ca/ca.crt" \
  "$SSL_CONFIG_DIR/ca/ca.key" \
  "$SSL_CONFIG_DIR/lan/san/local-san.cnf" \
  "$SSL_CONFIG_DIR/lan"
