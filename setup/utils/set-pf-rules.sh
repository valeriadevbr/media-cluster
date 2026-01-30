#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

echo "📋 Aplicando regras de firewall para ${PF_ANCHOR_NAME}..."

sudo pfctl -E -a "${PF_ANCHOR_NAME}" -F all
sudo pfctl -a "${PF_ANCHOR_NAME}" -f - <<EOF
# ==========================================
# DEFINIÇÕES (MACROS)
# ==========================================
if_ext = "${LAN_INTERFACE}"
ports_adm = "{ 22, 53, 51820 }"
ports_apps = "{ 8920, 32400, 50300, 53471 }"
ports_web = "{ 80, 443, 44000, 44300 }"

# ==========================================
# OPÇÕES
# ==========================================
set skip on lo0              # Ignora lo0 (mais rápido que regras de pass)
set block-policy return      # Resposta ativa para conexões negadas
scrub in all                 # Limpeza de pacotes (evita ataques de fragmentação)

# ==========================================
# REGRAS DE FILTRAGEM
# ==========================================

block log all
pass in quick on \$if_ext inet proto icmp from any to any icmp-type { echoreq, unreach }
pass in quick on \$if_ext proto { tcp, udp } from any to any port \$ports_adm
pass in quick on \$if_ext proto { tcp, udp } from any to any port \$ports_apps
pass in quick on \$if_ext proto { tcp, udp } from any to any port \$ports_web
pass out quick all
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
