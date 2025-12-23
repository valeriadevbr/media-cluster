#!/usr/bin/env bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
set +a

echo "📋 Aplicando regras de firewall para ${PF_ANCHOR_NAME}..."

sudo pfctl -E -a "${PF_ANCHOR_NAME}" -F all >/dev/null 2>&1
sudo pfctl -a "${PF_ANCHOR_NAME}" -f - >/dev/null 2>&1 << EOF
pass in quick proto tcp from any to any port 80 no state
pass out quick proto tcp from any port 80 to any no state
pass in quick proto tcp from any to any port 443 no state
pass out quick proto tcp from any port 443 to any no state
pass in quick proto tcp from any to any port 44300 no state
pass out quick proto tcp from any port 44300 to any no state
pass quick on en0 inet
EOF

if [ $? -eq 0 ]; then
    echo "✅ Regras aplicadas com sucesso!"
else
    echo "❌ Falha ao aplicar regras de firewall." >&2
    exit 1
fi

echo ""
echo "📊 Verificando regras ativas:"
sudo pfctl -a "${PF_ANCHOR_NAME}" -s rules

echo ""
echo "💡 Para verificar novamente: sudo pfctl -a ${PF_ANCHOR_NAME} -s rules"
