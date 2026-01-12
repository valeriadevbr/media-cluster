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
- containerPort: 8920
  hostPort: 8920
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

  echo "🔧 Ajustando configurações de rede..."
  docker exec "$MEDIA_CLUSTER_NAME-control-plane" ip link set eth0 mtu "${DOCKER_MTU}"
  docker exec "$MEDIA_CLUSTER_NAME-control-plane" ethtool -K eth0 tso on gso off gro off || true
  docker exec "$MEDIA_CLUSTER_NAME-control-plane" sysctl -w net.core.rmem_max=16777216
  docker exec "$MEDIA_CLUSTER_NAME-control-plane" sysctl -w net.core.wmem_max=16777216
  docker exec "$MEDIA_CLUSTER_NAME-control-plane" sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
  docker exec "$MEDIA_CLUSTER_NAME-control-plane" sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
else
  echo "Usando '$MEDIA_CLUSTER_NAME' existente..."
fi
