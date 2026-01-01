#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

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

if [[ "$OS" == "Darwin" ]]; then
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "${CERTS_PATH}/ca/ca.crt"
fi