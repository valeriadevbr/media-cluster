#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
set +a

echo "🧹 Iniciando limpeza COMPLETA..."

echo "1️⃣  Descarregando Cluster Media..."
"$(dirname -- "$0")/unload-media.sh"

echo "2️⃣  Descarregando Cluster Infra..."
"$(dirname -- "$0")/unload-infra.sh"

echo "✨ Todos os clusters foram removidos com sucesso!"
