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

  echo "🔧 Ajustando MTU diretamente no Node e Desativando Offloads (Fix para HostNetwork/Traefik)..."
  docker exec "$INFRA_CLUSTER_NAME-control-plane" ip link set eth0 mtu "${DOCKER_MTU}"
  docker exec "$INFRA_CLUSTER_NAME-control-plane" ethtool -K eth0 tso off gso off || true
else
  echo "Selecionando '$INFRA_CLUSTER_NAME' existente..."
  kubectl config use-context "kind-$INFRA_CLUSTER_NAME"
fi

echo "📦 Aplicando recursos do Cluster Infra via script..."
"${K8S_PATH}/apply-infra.sh"
