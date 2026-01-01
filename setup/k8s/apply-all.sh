#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
. "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

echo "Aplicando configurações. Raiz definida como: $SETUP_PATH"

# 1. Core e Storage
apply_with_subst "${K8S_PATH}/00-core/"
apply_with_subst "${K8S_PATH}/01-storage/"

# 2. Infraestrutura (DNS, Ingress, etc)
echo "🌐 Aplicando e aguardando infraestrutura (DNS)..."
apply_with_subst "${K8S_PATH}/02-infra/"
kubectl rollout status deployment/dns -n infra --timeout=60s

# 3. Aplicações
echo "📦 Aplicando restante das aplicações..."

if [ "${MEDIA_SERVERS_IN_CLUSTER}" = "true" ]; then
  echo "🎬 Applying Plex (Internal Cluster)..."
  apply_k8s_file "${K8S_PATH}/03-apps/02-plex-internal.conditional.yaml"
else
  echo "🔗 Applying Plex (External/Shim)..."
  apply_k8s_file "${K8S_PATH}/03-apps/02-plex-external.conditional.yaml"
fi

if [ "${MEDIA_SERVERS_IN_CLUSTER}" = "true" ]; then
  echo "🎬 Applying Emby (Internal Cluster)..."
  apply_k8s_file "${K8S_PATH}/03-apps/02-emby-internal.conditional.yaml"
else
  echo "🔗 Applying Emby (External/Shim)..."
  apply_k8s_file "${K8S_PATH}/03-apps/02-emby-external.conditional.yaml"
fi

apply_with_subst "${K8S_PATH}/03-apps/"

echo "Tudo aplicado com sucesso."
