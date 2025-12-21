#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
set +a

BOOTSTRAP_DIR="${SETUP_PATH}/k8s/bootstrap"

if [ -d "$BOOTSTRAP_DIR" ]; then
  echo "🚀 Iniciando Bootstrap do Cluster..."
  for script in $(ls "$BOOTSTRAP_DIR"/*.sh | sort); do
    if [ -x "$script" ] || [ "${script##*.}" == "sh" ]; then
      echo "--------------------------------------------------"
      echo "📜 Executando: $(basename "$script")"
      echo "--------------------------------------------------"
      source "$script"
    fi
  done
else
  echo "❌ Diretório de bootstrap não encontrado: $BOOTSTRAP_DIR"
  exit 1
fi

echo "✅ Setup concluído com sucesso!"
