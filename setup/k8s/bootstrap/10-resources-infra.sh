#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Aplicando configurações Infra. Raiz definida como: $SETUP_PATH"

echo "🌐 Aplicando Core (${CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/infra/00-core/" "$CLUSTER_NAME"
kubectl rollout restart deployment coredns -n kube-system --context="kind-${CLUSTER_NAME}"
kubectl rollout status deployment coredns -n kube-system --context="kind-${CLUSTER_NAME}"

echo "💾 Aplicando Storage (${CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/infra/01-storage/" "$CLUSTER_NAME"

echo "🌐 Aplicando Ingress (${CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/infra/02-ingress/" "$CLUSTER_NAME"

echo "📦 Aplicando Apps (BIND) (${CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/infra/03-apps/" "$CLUSTER_NAME"

echo "🔧 Aplicando Maintenance (Backup) (${CLUSTER_NAME})..."
apply_with_subst "${K8S_PATH}/infra/04-maintenance/" "$CLUSTER_NAME"

echo "⏳ Aguardando BIND..."
kubectl rollout status deployment/dns -n infra --context="kind-${CLUSTER_NAME}" --timeout=60s

echo "Tudo aplicado com sucesso no cluster Infra."
