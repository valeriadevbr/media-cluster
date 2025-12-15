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
# --- OPÇÕES GERAIS ---
# CRUCIAL: Diz ao firewall para NÃO filtrar tráfego na Loopback
# Isso restaura o acesso ao 192.168.2.1 e localhost
set skip on lo0

# --- REGRAS DE NAT ---
# Mascarar saída para internet
nat on $INET_IFace from 10.13.13.0/24 to any -> ($INET_IFace)

# --- REGRAS DE FILTRO ---
# Permitir tudo na interface da VPN (entrada e saída)
pass quick on $WG_IFace inet

# Forçar a aceitação de pacotes destinados ao IP local vindo da VPN
# (Caso o 'set skip' não capture devido à troca de interface)
pass in quick from 10.13.13.0/24 to 192.168.2.1
EOF
) | pfctl -f -

echo "Regras aplicadas: NAT em $INET_IFace e Skip na Loopback."
