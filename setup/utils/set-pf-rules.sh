#!/usr/bin/env bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
set +a

echo "📋 Aplicando regras de firewall para ${PF_ANCHOR_NAME}..."

sudo pfctl -E
sudo pfctl -a "${PF_ANCHOR_NAME}" -F all
sudo pfctl -a "${PF_ANCHOR_NAME}" -f - << EOF
# Allow all traffic on ethernet interface
pass quick on en0 inet

# Port 443: Bypass Application Firewall inspection (fix timeout issue)
pass in quick proto tcp from any to any port 443 no state
pass out quick proto tcp from any port 443 to any no state

# Allow traffic from LAN to common services
pass on en0 proto tcp from ${DOCKER_HOST_SUBNET} to port 22
pass on en0 proto { tcp, udp } from ${DOCKER_HOST_SUBNET} to port 53
pass on en0 proto tcp from ${DOCKER_HOST_SUBNET} to port 80
pass on en0 proto tcp from ${DOCKER_HOST_SUBNET} to port 443

# Allow ICMP echo requests from local network
pass inet proto icmp from ${DOCKER_HOST_SUBNET} icmp-type echoreq
EOF

echo "✅ Regras aplicadas com sucesso!"
echo ""
echo "📊 Verificando regras ativas:"
sudo pfctl -a "${PF_ANCHOR_NAME}" -s rules

echo ""
echo "💡 Para verificar novamente: sudo pfctl -a ${PF_ANCHOR_NAME} -s rules"
