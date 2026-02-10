#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
set +a

echo "🧹 Iniciando limpeza COMPLETA..."

echo "1️⃣  Limpando Contexto Media..."
"$(dirname -- "$0")/unload-media.sh"

echo "2️⃣  Limpando Contexto Infra..."
"$(dirname -- "$0")/unload-infra.sh"

echo "🔥 Deletando Cluster Kind Unificado '${CLUSTER_NAME}'..."
kind delete cluster --name "${CLUSTER_NAME}"

echo "✨ Tudo foi removido com sucesso!"
