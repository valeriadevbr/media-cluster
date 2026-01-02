#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

if ! kind get clusters | grep -q "$MEDIA_CLUSTER_NAME"; then
  echo "Criando cluster Kind '$MEDIA_CLUSTER_NAME'..."

  KIND_CONFIG=$(cat "${SETUP_PATH}/k8s/bootstrap/resources/kind-config-media.yaml")

  if [ "${MEDIA_SERVERS_IN_CLUSTER}" = "true" ]; then
    echo "🔓 Injecting Media Server ports using yq..."
    export MEDIA_PORTS_YAML=$(
      cat <<EOF
- containerPort: 8096
  hostPort: 8096
  protocol: TCP
- containerPort: 7359
  hostPort: 7359
  protocol: UDP
- containerPort: 32400
  hostPort: 32400
  protocol: TCP
- containerPort: 32410
  hostPort: 32410
  protocol: UDP
- containerPort: 32412
  hostPort: 32412
  protocol: UDP
- containerPort: 32413
  hostPort: 32413
  protocol: UDP
- containerPort: 32414
  hostPort: 32414
  protocol: UDP
EOF
    )
    KIND_CONFIG=$(echo "$KIND_CONFIG" | yq eval '.nodes[0].extraPortMappings += env(MEDIA_PORTS_YAML)' -)
  fi
  echo "$KIND_CONFIG" | envsubst | kind create cluster --name "$MEDIA_CLUSTER_NAME" --image kindest/node:v1.31.1 --config -

  echo "🔧 Ajustando MTU diretamente no Node e Desativando Offloads (Fix para HostNetwork/Traefik)..."
  docker exec "$MEDIA_CLUSTER_NAME-control-plane" ip link set eth0 mtu "${DOCKER_MTU}"
  docker exec "$MEDIA_CLUSTER_NAME-control-plane" ethtool -K eth0 tso off gso off || true
else
  echo "Selecionando '$MEDIA_CLUSTER_NAME' existente..."
  kubectl config use-context "kind-$MEDIA_CLUSTER_NAME"
fi
