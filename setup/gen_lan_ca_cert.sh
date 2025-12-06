#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/.env"

SSL_CONFIG_PATH="${CONFIGS_PATH}/ssl"

openssl genrsa -out $SSL_CONFIG_PATH/ca/ca.key 4096
openssl req \
  -x509 \
  -new \
  -nodes \
  -sha256 \
  -days 1825 \
  -subj "/CN=DevilCOM Network" \
  -key $CONFIGS_PATH/ssl/ca/ca.key \
  -out $CONFIGS_PATH/ssl/ca/ca.crt

sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CONFIGS_PATH/ssl/ca/ca.crt
