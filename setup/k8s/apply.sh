#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../utils/load-env.sh"
set +a

# Verifica se o usuário passou um argumento
if [ -z "$1" ]; then
  echo "Uso: $0 <caminho_do_arquivo_yaml>"
  exit 1
fi

# Chama a função exportada pelo k8s-utils.sh
apply_k8s_file "$1"
