#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/../.env"

openssl genrsa -out "${CERTS_PATH}/ca/ca.key" 4096
openssl req \
  -x509 \
  -new \
  -nodes \
  -sha256 \
  -days 1825 \
  -subj "/CN=DevilCOM Network" \
  -key "${CERTS_PATH}/ca/ca.key" \
  -out "${CERTS_PATH}/ca/ca.crt"

sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "${CERTS_PATH}/ca/ca.crt"
