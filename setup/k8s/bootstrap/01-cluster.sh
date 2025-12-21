#!/bin/bash
set -e
set -a
source "$(dirname -- "${BASH_SOURCE[0]}")/../../.env"
source "${SETUP_PATH}/includes/k8s-utils.sh"
set +a

if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
  echo "Criando cluster Kind '$CLUSTER_NAME'..."
  subst_manifest "${SETUP_PATH}/k8s/kind-config.yaml" |
    kind create cluster --name "$CLUSTER_NAME" --image kindest/node:v1.31.1 --config -

  echo "🔧 Ajustando MTU diretamente no Node e Desativando Offloads (Fix para HostNetwork/Traefik)..."
  docker exec "$CLUSTER_NAME-control-plane" ip link set eth0 mtu "${DOCKER_MTU}"
  docker exec "$CLUSTER_NAME-control-plane" ethtool -K eth0 tso off gso off || true
else
  echo "Selecionando '$CLUSTER_NAME' existente..."
  kubectl config use-context "kind-$CLUSTER_NAME"
fi
