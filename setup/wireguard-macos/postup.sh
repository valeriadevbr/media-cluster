#!/bin/bash

# $1 recebe o nome da interface (ex: utun4) passado pelo %i no wg0.conf
WG_IFace=$1
# Sua interface de internet física
INET_IFace="en0"

# Habilitar forwarding no kernel
/usr/sbin/sysctl -w net.inet.ip.forwarding=1

# Limpar regras antigas
pfctl -F nat

# Aplicar novas regras
(
  cat <<EOF
nat on $INET_IFace from 10.13.13.0/24 to any -> ($INET_IFace)
rdr on $WG_IFace inet proto { tcp, udp } from 10.13.13.0/24 to 192.168.2.1 -> 10.13.13.1
pass quick on $WG_IFace inet
pass in quick on $INET_IFace from 10.13.13.0/24 to 192.168.2.0/24
pass out quick on $INET_IFace from 192.168.2.0/24 to 10.13.13.0/24
EOF
) | pfctl -f -

echo "Regras aplicadas: NAT em $INET_IFace."
