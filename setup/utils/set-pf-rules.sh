#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

echo "📋 Aplicando regras de firewall para ${PF_ANCHOR_NAME}..."

# Garantir que a interface de log existe para visualizar pacotes bloqueados
if ! ifconfig pflog0 >/dev/null 2>&1; then
    echo "🌐 Criando interface de log pflog0..."
    sudo ifconfig pflog0 create
fi

# ==========================================
# CONFIGURAÇÕES DE PORTAS (BASH)
# ==========================================
ports_adm="{22,53,853,5900,51820}"
ports_apps="{8096,8920,32400,50300,53471}"
ports_web="{80,443,44000,44300}"

sudo pfctl -E -a "${PF_ANCHOR_NAME}" -F all
sudo pfctl -a "${PF_ANCHOR_NAME}" -f - <<EOF

# ==========================================
# OPÇÕES
# ==========================================
set skip on lo0              # Ignora lo0 (localhost)
set block-policy return      # Resposta ativa para conexões negadas
scrub in all                 # Limpeza de pacotes (evita ataques de fragmentação)

# ==========================================
# REGRAS DE FILTRAGEM
# ==========================================

# 1. LIBERAÇÃO TOTAL DE SAÍDA
pass out quick all flags any allow-opts

pass quick on bridge100 all
pass quick on bridge101 all
pass quick on bridge102 all

# 2. REGRAS SILENCIOSAS (SEM LOG) - REDE LOCAL E CONFIANÇA
pass in quick on ${LAN_INTERFACE} from 192.168.2.0/24 to any flags any allow-opts
pass in quick on ${LAN_INTERFACE} proto udp from any to any port {5353,1900,1902,56700,57621,9999,10101,546,547,67,68,3702}
pass in quick on ${LAN_INTERFACE} proto igmp from any to any allow-opts
pass in quick on ${LAN_INTERFACE} inet6 proto icmp6 all
block in quick on ${LAN_INTERFACE} proto udp from any to any port {137,138}

# 3. PASSAGEM SILENCIOSA DE SERVIÇOS CONFIGURADOS
pass in quick on ${LAN_INTERFACE} proto tcp from any to any port ${ports_adm} flags S/SA keep state
pass in quick on ${LAN_INTERFACE} proto tcp from any to any port ${ports_apps} flags any keep state
pass in quick on ${LAN_INTERFACE} proto tcp from any to any port ${ports_web} flags any keep state

# Permitir UDP para as mesmas portas (DNS, VPN, Discovery, QUIC)
pass in quick on ${LAN_INTERFACE} proto udp from any to any port ${ports_adm}
pass in quick on ${LAN_INTERFACE} proto udp from any to any port ${ports_apps}
pass in quick on ${LAN_INTERFACE} proto udp from any to any port ${ports_web}

# 4. LOG DE SEGURANÇA (SCANNERS)
# Logamos apenas novas tentativas de conexão TCP (SYN) para portas fechadas
block return log quick on ${LAN_INTERFACE} proto tcp flags S/SA

# 5. BLOQUEIO SILENCIOSO DO "LIXO" (QUIC, RESÍDUOS, SCANNERS UDP)
# Bloqueia tudo o que sobrou sem gerar logs no tcpdump
block in quick on ${LAN_INTERFACE} all

# Regras de Suporte (ICMP)
pass in quick on ${LAN_INTERFACE} inet proto icmp from any to any icmp-type {echoreq, unreach}

# Tunéis VPN
pass quick on utun4 all
pass quick on utun5 all
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
