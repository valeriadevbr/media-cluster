#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
. "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

if [ -z "$1" ]; then
  echo "Uso: $0 <caminho_do_arquivo_yaml> [cluster]"
  echo "Se não informado, cluster: \"$MEDIA_CLUSTER_NAME\"."
  exit 1
fi

CLUSTER="${2:-$MEDIA_CLUSTER_NAME}"
apply_k8s_file "$1" "$CLUSTER"
