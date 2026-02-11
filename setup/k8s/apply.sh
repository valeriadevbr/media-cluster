#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
. "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

if [ -z "$1" ]; then
  echo "Uso: $0 <caminho_do_arquivo_yaml> [contexto]"
  echo "Se não informado, contexto: \"$K8S_CONTEXT\"."
  exit 1
fi

CONTEXT="${2:-$K8S_CONTEXT}"
apply_k8s_file "$1" "$CONTEXT"
