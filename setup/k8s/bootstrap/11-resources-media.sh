#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Aplicando configurações. Raiz definida como: $SETUP_PATH"

echo "🌐 Aplicando Core (${K8S_CONTEXT})..."
apply_with_subst "${K8S_PATH}/media/00-core/" "$K8S_CONTEXT"

echo "🌐 Aplicando Storage (${K8S_CONTEXT})..."
apply_with_subst "${K8S_PATH}/media/01-storage/" "$K8S_CONTEXT"

echo "🌐 Aplicando Ingress (${K8S_CONTEXT})..."
apply_with_subst "${K8S_PATH}/media/02-ingress/" "$K8S_CONTEXT"

echo "📦 Aplicando restante das aplicações (${K8S_CONTEXT})..."

if [ "${MEDIA_SERVERS_IN_CLUSTER}" = "true" ]; then
  echo "🎬 Aplicando Plex (Internal Cluster)..."
  apply_k8s_file "${K8S_PATH}/media/03-apps/02-plex-internal.conditional.yaml" "$K8S_CONTEXT"
else
  echo "🔗 Aplicando Plex (External/Shim)..."
  apply_k8s_file "${K8S_PATH}/media/03-apps/02-plex-external.conditional.yaml" "$K8S_CONTEXT"
fi

if [ "${MEDIA_SERVERS_IN_CLUSTER}" = "true" ]; then
  echo "🎬 Aplicando Emby (Internal Cluster)..."
  apply_k8s_file "${K8S_PATH}/media/03-apps/02-emby-internal.conditional.yaml" "$K8S_CONTEXT"
else
  echo "🔗 Aplicando Emby (External/Shim)..."
  apply_k8s_file "${K8S_PATH}/media/03-apps/02-emby-external.conditional.yaml" "$K8S_CONTEXT"
fi

apply_with_subst "${K8S_PATH}/media/03-apps/" "$K8S_CONTEXT"

echo "Tudo aplicado com sucesso."
