#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
source "${SETUP_PATH}/includes/k8s-utils.sh"
set +a

BOOTSTRAP_PATH="${K8S_PATH}/bootstrap"

echo "${BOOTSTRAP_PATH}"

if [ -d "$BOOTSTRAP_PATH" ]; then
  echo "🚀 Iniciando Bootstrap do Cluster..."
  for script in $(ls "$BOOTSTRAP_PATH"/*.sh | sort); do
    if [ -x "$script" ] || [ "${script##*.}" == "sh" ]; then
      echo "--------------------------------------------------"
      echo "📜 Executando: $(basename "$script")"
      echo "--------------------------------------------------"
      source "$script"
    fi
  done
else
  echo "❌ Diretório de bootstrap não encontrado: $BOOTSTRAP_PATH"
  exit 1
fi

echo "✅ Setup concluído com sucesso!"
