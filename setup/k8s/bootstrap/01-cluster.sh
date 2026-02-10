#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
  echo "Criando cluster Kind unificado '$CLUSTER_NAME'..."

  KIND_CONFIG_FILE="${K8S_PATH}/bootstrap/resources/kind-config.yaml"
  KIND_CONFIG=$(cat "${KIND_CONFIG_FILE}")

  echo "$KIND_CONFIG" | envsubst | kind create cluster --name "$CLUSTER_NAME" --image kindest/node:v1.31.1 --config -

  echo "🔧 Ajustando configurações de rede..."
  docker exec "$CLUSTER_NAME-control-plane" ip link set eth0 mtu "${DOCKER_MTU}"
  docker exec "$CLUSTER_NAME-control-plane" ethtool -K eth0 tso on gso off gro off || true
  docker exec "$CLUSTER_NAME-control-plane" sysctl -w net.core.rmem_max=16777216
  docker exec "$CLUSTER_NAME-control-plane" sysctl -w net.core.wmem_max=16777216
  docker exec "$CLUSTER_NAME-control-plane" sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
  docker exec "$CLUSTER_NAME-control-plane" sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
  docker exec "$CLUSTER_NAME-control-plane" sysctl -w net.ipv4.ip_unprivileged_port_start=0
else
  echo "Utilizando '$CLUSTER_NAME' existente..."
fi

echo "✅ Cluster Unificado pronto."
