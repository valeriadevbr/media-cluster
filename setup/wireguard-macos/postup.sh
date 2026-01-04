#!/bin/bash

# $1 recebe o nome da interface (ex: utun4) passado pelo %i no wg0.conf
WG_IFace=$1
INET_IFace="en0"
PF_ANCHOR_NAME="com.apple/wireguard"

/usr/sbin/sysctl -w net.inet.ip.forwarding=1

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

sudo pfctl -E -a "${PF_ANCHOR_NAME}" -F all > /dev/null
sudo pfctl -a "${PF_ANCHOR_NAME}" -f - << EOF > /dev/null
set skip on lo0

# 1. NAT: Mascarar saída da VPN para a interface física
nat on $INET_IFace inet from ${WG_SUBNET} to any -> 192.168.2.1

# 2. RDR: Regra específica de redirecionamento
# rdr on $WG_IFace inet proto { tcp, udp, icmp } from ${WG_SUBNET} to ${DOCKER_HOST_IP} -> ${WG_SERVER_IP}

# 3. Permite tudo dentro do túnel (necessário para o RDR e comunicação interna)
pass quick on $WG_IFace inet

# Permite que o tráfego que VEIO da VPN (agora com NAT) SAIA pela placa física para a rede Docker
pass out quick on $INET_IFace inet from any to ${DOCKER_HOST_SUBNET} keep state 

pass in quick on $INET_IFace inet from ${DOCKER_HOST_SUBNET} to 192.168.2.1
EOF

if [ $? -eq 0 ]; then
  echo "✅ Regras aplicadas com sucesso!"
  echo "Regras aplicadas na âncora '${PF_ANCHOR_NAME}'."
  echo ""
  echo "💡 Para verificar novamente: sudo pfctl -a ${PF_ANCHOR_NAME} -s rules"
else
  echo "❌ Falha ao aplicar regras de firewall." >&2
  exit 1
fi
