#!/usr/bin/env bash
set -e

ANCHOR_NAME="media.lan"

echo "📋 Aplicando regras de firewall para ${ANCHOR_NAME}..."

# Load rules via stdin using here-doc
sudo pfctl -a "${ANCHOR_NAME}" -f - << 'EOF'
# Allow all traffic on ethernet interface
pass quick on en0 inet

# Port 443: Bypass Application Firewall inspection (fix timeout issue)
pass in quick proto tcp from any to any port 443 no state
pass out quick proto tcp from any port 443 to any no state

# Allow traffic from LAN to common services
pass on en0 proto tcp from 192.168.2.0/24 to port 53
pass on en0 proto tcp from 192.168.2.0/24 to port 80
pass on en0 proto tcp from 192.168.2.0/24 to port 443

# Allow ICMP echo requests from local network
pass inet proto icmp from 192.168.2.0/16 icmp-type echoreq
EOF

echo "✅ Regras aplicadas com sucesso!"
echo ""
echo "📊 Verificando regras ativas:"
sudo pfctl -a "${ANCHOR_NAME}" -s rules

echo ""
echo "💡 Para verificar novamente: sudo pfctl -a ${ANCHOR_NAME} -s rules"
