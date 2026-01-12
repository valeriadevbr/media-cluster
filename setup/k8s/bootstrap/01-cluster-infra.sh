#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

if ! kind get clusters | grep -q "$INFRA_CLUSTER_NAME"; then
  echo "Criando cluster Kind '$INFRA_CLUSTER_NAME'..."

  KIND_CONFIG=$(cat "${SETUP_PATH}/k8s/bootstrap/resources/kind-config-infra.yaml")

  echo "$KIND_CONFIG" | envsubst | kind create cluster --name "$INFRA_CLUSTER_NAME" --image kindest/node:v1.31.1 --config -

  echo "🔧 Ajustando configurações de rede..."
  docker exec "$INFRA_CLUSTER_NAME-control-plane" ip link set eth0 mtu "${DOCKER_MTU}"
  docker exec "$INFRA_CLUSTER_NAME-control-plane" ethtool -K eth0 tso on gso off gro off || true
  docker exec "$INFRA_CLUSTER_NAME-control-plane" sysctl -w net.core.rmem_max=16777216
  docker exec "$INFRA_CLUSTER_NAME-control-plane" sysctl -w net.core.wmem_max=16777216
  docker exec "$INFRA_CLUSTER_NAME-control-plane" sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
  docker exec "$INFRA_CLUSTER_NAME-control-plane" sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
  docker exec "$INFRA_CLUSTER_NAME-control-plane" sysctl -w net.ipv4.ip_unprivileged_port_start=0
else
  echo "Utilizando '$INFRA_CLUSTER_NAME' existente..."
fi

echo "✅ Cluster Infra pronto."
