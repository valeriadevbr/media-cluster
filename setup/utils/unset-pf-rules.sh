#!/usr/bin/env bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
set +a

echo "🧹 Removendo regras de firewall para ${PF_ANCHOR_NAME}..."

# Flush all rules for the anchor
sudo pfctl -a "${PF_ANCHOR_NAME}" -F all

echo "✅ Regras removidas com sucesso!"
echo ""
echo "📊 Verificando status (deve estar vazio):"
sudo pfctl -a "${PF_ANCHOR_NAME}" -s rules
