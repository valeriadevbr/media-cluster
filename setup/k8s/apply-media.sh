#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
. "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

echo "Aplicando configurações. Raiz definida como: $SETUP_PATH"

echo "🌐 Aplicando Core e Storage (${MEDIA_CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/media/00-core/" "$MEDIA_CLUSTER_NAME"
apply_with_subst "${K8S_PATH}/media/01-storage/" "$MEDIA_CLUSTER_NAME"

echo "🌐 Aplicando Ingress (${MEDIA_CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/media/02-ingress/" "$MEDIA_CLUSTER_NAME"

echo "📦 Aplicando restante das aplicações (${MEDIA_CLUSTER_NAME})..."

if [ "${MEDIA_SERVERS_IN_CLUSTER}" = "true" ]; then
  echo "🎬 Aplicando Plex (Internal Cluster)..."
  apply_k8s_file "${K8S_PATH}/media/03-apps/02-plex-internal.conditional.yaml" "$MEDIA_CLUSTER_NAME"
else
  echo "🔗 Aplicando Plex (External/Shim)..."
  apply_k8s_file "${K8S_PATH}/media/03-apps/02-plex-external.conditional.yaml" "$MEDIA_CLUSTER_NAME"
fi

if [ "${MEDIA_SERVERS_IN_CLUSTER}" = "true" ]; then
  echo "🎬 Aplicando Emby (Internal Cluster)..."
  apply_k8s_file "${K8S_PATH}/media/03-apps/02-emby-internal.conditional.yaml" "$MEDIA_CLUSTER_NAME"
else
  echo "🔗 Aplicando Emby (External/Shim)..."
  apply_k8s_file "${K8S_PATH}/media/03-apps/02-emby-external.conditional.yaml" "$MEDIA_CLUSTER_NAME"
fi

apply_with_subst "${K8S_PATH}/media/03-apps/" "$MEDIA_CLUSTER_NAME"

echo "Tudo aplicado com sucesso."
