#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/load-env.sh"
set +a

generate_local_cert \
  "media.lan" \
  "$CERTS_PATH/ca/ca.crt" \
  "$CERTS_PATH/ca/ca.key" \
  "$CERTS_PATH/lan/san/local-san.cnf" \
  "$CERTS_PATH/lan"
