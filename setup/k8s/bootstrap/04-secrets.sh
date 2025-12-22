#!/bin/bash
set -e

echo "Criando secret TLS..."

create_tls_secret media-lan-tls ingress-traefik \
  "${CERTS_PATH}/lan/cert.crt" \
  "${CERTS_PATH}/lan/cert.key"

create_tls_secret media-lan-tls infra \
  "${CERTS_PATH}/lan/cert.crt" \
  "${CERTS_PATH}/lan/cert.key"

create_tls_secret media-lan-tls media \
  "${CERTS_PATH}/lan/cert.crt" \
  "${CERTS_PATH}/lan/cert.key"

create_tls_secret media-wan-tls ingress-traefik \
  "${CERTS_PATH}/wan/apedamo.duckdns.org.crt" \
  "${CERTS_PATH}/wan/apedamo.duckdns.org.key"

create_tls_secret media-wan-tls media \
  "${CERTS_PATH}/wan/apedamo.duckdns.org.crt" \
  "${CERTS_PATH}/wan/apedamo.duckdns.org.key"
