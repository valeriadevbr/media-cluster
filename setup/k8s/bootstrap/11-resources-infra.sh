#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Aplicando configurações Infra. Raiz definida como: $SETUP_PATH"

echo "🌐 Aplicando Core (${K8S_CONTEXT})..."
apply_with_subst "${K8S_PATH}/infra/00-core/" "$K8S_CONTEXT"
kubectl rollout restart deployment coredns -n kube-system --context="${K8S_CONTEXT}"
kubectl rollout status deployment coredns -n kube-system --context="${K8S_CONTEXT}"

echo "💾 Aplicando Storage (${K8S_CONTEXT})..."
apply_with_subst "${K8S_PATH}/infra/01-storage/" "$K8S_CONTEXT"

echo "🌐 Aplicando Ingress (${K8S_CONTEXT})..."
apply_with_subst "${K8S_PATH}/infra/02-ingress/" "$K8S_CONTEXT"

echo "📦 Aplicando Apps (BIND) (${K8S_CONTEXT})..."
apply_with_subst "${K8S_PATH}/infra/03-apps/" "$K8S_CONTEXT"

echo "🔧 Aplicando Maintenance (Backup) (${K8S_CONTEXT})..."
apply_with_subst "${K8S_PATH}/infra/04-maintenance/" "$K8S_CONTEXT"

echo "⏳ Aguardando BIND..."
kubectl rollout status deployment/dns -n infra --context="${K8S_CONTEXT}" --timeout=60s

echo "Tudo aplicado com sucesso no cluster Infra."
