#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

echo "📋 Aplicando regras de firewall para ${PF_ANCHOR_NAME}..."

sudo pfctl -E -a "${PF_ANCHOR_NAME}" -F all
sudo pfctl -a "${PF_ANCHOR_NAME}" -f - <<'EOF'
# ==========================================
# DEFINIÇÕES (MACROS)
# ==========================================
if_ext = "en0"
if_vpn = "utun"
ports_web = "{ 22, 80, 443, 44000, 44300 }"

# ==========================================
# OPÇÕES
# ==========================================
set skip on lo0              # Ignora lo0 (mais rápido que regras de pass)
set block-policy return      # Resposta ativa para conexões negadas
scrub in all                 # Limpeza de pacotes (evita ataques de fragmentação)

# ==========================================
# REGRAS DE FILTRAGEM
# ==========================================

# 1. POLÍTICA PADRÃO: Bloqueia e loga tudo por padrão.
# Sem 'quick', para permitir que as regras abaixo sobrescrevam esta decisão.
block log all

# 2. INTERFACES DE CONFIANÇA (VPN)
# Se você quer que a VPN acesse TUDO no host e no Docker:
pass quick on $if_vpn all

# 3. REGRAS ESPECÍFICAS PARA EN0 (Entrada via Internet/LAN física)
# Liberar tráfego Web/SSH para o Host ou Docker
pass in quick on $if_ext proto { tcp, udp } from any to any port $ports_web

# 4. DNS (Apenas para quem está na rede física en0)
# (A VPN já foi liberada acima pelo 'pass quick on $if_vpn')
pass in quick on $if_ext proto udp from $if_ext:network to any port 53

# 5. SAÍDA DE TRÁFEGO
# Permite que o Host e os Containers acessem a internet
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
