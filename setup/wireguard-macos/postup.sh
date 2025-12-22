#!/bin/bash

# $1 recebe o nome da interface (ex: utun4) passado pelo %i no wg0.conf
WG_IFace=$1
INET_IFace="en0"
ANCHOR_NAME="com.apple/wireguard"

/usr/sbin/sysctl -w net.inet.ip.forwarding=1

if [[ "$(uname -s)" == "Darwin" ]]; then
  pfctl -E
  pfctl -a "${ANCHOR_NAME}" -F all > /dev/null

  (
    cat <<EOF
nat on $INET_IFace inet from ${WG_SUBNET} to any -> ($INET_IFace)
rdr on $WG_IFace inet proto { tcp, udp, icmp } from ${WG_SUBNET} to ${DOCKER_HOST_IP} -> ${WG_SERVER_IP}
pass quick on $WG_IFace inet
pass in quick on $INET_IFace from ${WG_SUBNET} to ${DOCKER_HOST_SUBNET}
pass out quick on $INET_IFace from ${DOCKER_HOST_SUBNET} to ${WG_SUBNET}
EOF
  ) | pfctl -a "${ANCHOR_NAME}" -f -

  echo "Regras aplicadas na âncora '${ANCHOR_NAME}'."
  echo ""
  echo "💡 Para verificar novamente: sudo pfctl -a ${ANCHOR_NAME} -s rules"
fi
