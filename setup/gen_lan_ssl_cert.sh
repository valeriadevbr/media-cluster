#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/.env"
source "$(dirname -- "$0")/includes/generate_local_cert.sh"

SSL_CONFIG_PATH="${CONFIGS_PATH}/ssl"

generate_local_cert \
  "localhost" \
  "$SSL_CONFIG_PATH/ca/ca.crt" \
  "$SSL_CONFIG_PATH/ca/ca.key" \
  "$SSL_CONFIG_PATH/lan/san/local-san.cnf" \
  "$SSL_CONFIG_PATH/lan"
