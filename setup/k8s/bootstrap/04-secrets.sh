#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Criando secret TLS..."

create_tls_secret media-lan-tls ingress-traefik \
  "${CERTS_PATH}/lan/cert.crt" \
  "${CERTS_PATH}/lan/cert.key"

# create_tls_secret media-wan-tls ingress-traefik \
#   "${CERTS_PATH}/wan/cert.crt" \
#   "${CERTS_PATH}/wan/cert.key"

create_tls_secret media-lan-tls media \
  "${CERTS_PATH}/lan/cert.crt" \
  "${CERTS_PATH}/lan/cert.key"

# create_tls_secret media-wan-tls media \
#   "${CERTS_PATH}/wan/cert.crt" \
#   "${CERTS_PATH}/wan/cert.key"
