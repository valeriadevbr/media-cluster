#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

BOOTSTRAP_PATH="${K8S_PATH}/bootstrap"

echo "${BOOTSTRAP_PATH}"

if [ -d "$BOOTSTRAP_PATH" ]; then
  echo "🚀 Iniciando Bootstrap dos Clusters..."
  for script in $(ls "$BOOTSTRAP_PATH"/*.sh | sort); do
    if [ -x "$script" ] || [ "${script##*.}" == "sh" ]; then
      echo "--------------------------------------------------"
      echo "📜 Executando: $(basename "$script")"
      echo "--------------------------------------------------"
      "$script"
    fi
  done
else
  echo "❌ Diretório de bootstrap não encontrado: $BOOTSTRAP_PATH"
  exit 1
fi

echo "✅ Setup concluído com sucesso!"
