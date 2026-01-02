#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
. "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

echo "Aplicando configurações Infra. Raiz definida como: $SETUP_PATH"

echo "🌐 Aplicando Core (${INFRA_CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/infra/00-core/" "$INFRA_CLUSTER_NAME"

echo "💾 Aplicando Storage (${INFRA_CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/infra/01-storage/" "$INFRA_CLUSTER_NAME"

echo "📦 Aplicando Apps (BIND) (${INFRA_CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/infra/03-apps/" "$INFRA_CLUSTER_NAME"

echo "⏳ Aguardando BIND..."
kubectl rollout status deployment/dns -n infra --context="kind-${INFRA_CLUSTER_NAME}" --timeout=60s

echo "Tudo aplicado com sucesso no cluster Infra."
