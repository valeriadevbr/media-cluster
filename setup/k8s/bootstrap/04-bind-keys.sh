#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

readonly TSIG_KEYS_PATH="${CONFIGS_PATH}/bind/config"
readonly TSIG_KEY_EXTERNALDNS="${TSIG_KEYS_PATH}/named.conf.externaldns-key"
readonly TSIG_KEY_RDNC="${TSIG_KEYS_PATH}/named.conf.rdnc-key"

if [ ! -s "$TSIG_KEY_EXTERNALDNS" ]; then
  echo "🔑 Gerando chave TSIG para ExternalDNS..."
  tsig-keygen -a HMAC-SHA256 externaldns-key >"$TSIG_KEY_EXTERNALDNS"
fi

if [ ! -s "$TSIG_KEY_RDNC" ]; then
  echo "🔑 Gerando chave TSIG para RDNC..."
  tsig-keygen -a HMAC-SHA256 rdnc-key >"$TSIG_KEY_RDNC"
fi
