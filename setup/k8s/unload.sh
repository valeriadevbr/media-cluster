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

echo "🧹 Removendo pod sysctl-patch (OrbStack)..."
kubectl delete pod sysctl-patch --ignore-not-found=true

echo "✨ Tudo foi removido com sucesso!"
