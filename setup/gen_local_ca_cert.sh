#!/bin/bash

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/includes/setup_vars.sh"

# openssl genrsa -out $CONFIGS_DIR/ssl/ca/ca.key 4096
# openssl req \
#   -x509 \
#   -new \
#   -nodes \
#   -sha256 \
#   -days 1825 \
#   -subj "/CN=DevilCOM Network" \
#   -key $CONFIGS_DIR/ssl/ca/ca.key \
#   -out $CONFIGS_DIR/ssl/ca/ca.crt

sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CONFIGS_DIR/ssl/ca/ca.crt
