#!/bin/bash

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/includes/setup_vars.sh"
source "$(dirname -- "$0")/includes/generate_cert.sh"

generate_cert \
  "sonarr.local" \
  "$SSL_CONFIG_DIR/ca/ca.crt" \
  "$SSL_CONFIG_DIR/ca/ca.key" \
  "$SSL_CONFIG_DIR/local/san/sonarr.local-san.cnf" \
  "$SSL_CONFIG_DIR/local/sonarr.local.pfx"

generate_cert \
  "radarr.local" \
  "$SSL_CONFIG_DIR/ca/ca.crt" \
  "$SSL_CONFIG_DIR/ca/ca.key" \
  "$SSL_CONFIG_DIR/local/san/radarr.local-san.cnf" \
  "$SSL_CONFIG_DIR/local/radarr.local.pfx"

generate_cert \
  "prowlarr.local" \
  "$SSL_CONFIG_DIR/ca/ca.crt" \
  "$SSL_CONFIG_DIR/ca/ca.key" \
  "$SSL_CONFIG_DIR/local/san/prowlarr.local-san.cnf" \
  "$SSL_CONFIG_DIR/local/prowlarr.local.pfx"
