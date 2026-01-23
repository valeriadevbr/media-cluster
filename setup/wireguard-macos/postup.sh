#!/bin/bash

# $1 recebe o nome da interface (ex: utun4) passado pelo %i no wg0.conf
WG_IFace=$1
INET_IFace="${LAN_INTERFACE}"
PF_ANCHOR_NAME="com.apple/wireguard"

/usr/sbin/sysctl -w net.inet.ip.forwarding=1

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

sudo pfctl -E -a "${PF_ANCHOR_NAME}" -F all > /dev/null
sudo pfctl -a "${PF_ANCHOR_NAME}" -f - << EOF > /dev/null
set skip on lo0
# nat on $INET_IFace inet from ${WG_SUBNET} to any -> 192.168.2.1
pass in quick on $WG_IFace inet from ${WG_SUBNET} to ${DOCKER_HOST_SUBNET}
pass out quick on $INET_IFace inet from any to ${DOCKER_HOST_SUBNET}
pass in quick on $INET_IFace inet from ${DOCKER_HOST_SUBNET} to ${WG_SUBNET}
pass out quick on $WG_IFace inet from ${DOCKER_HOST_SUBNET} to ${WG_SUBNET}
pass quick on $WG_IFace inet all
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
