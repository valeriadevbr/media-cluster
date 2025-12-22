#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
set +a

echo "🧹 Iniciando limpeza dos resources no cluster '${CLUSTER_NAME}'..."

# 1. Remover Apps e Infra
echo "🔻 Removendo Aplicações (03-apps)..."
kubectl delete -f "${K8S_PATH}/03-apps/" --ignore-not-found

echo "🔻 Removendo Infraestrutura (02-infra)..."
kubectl delete -f "${K8S_PATH}/02-infra/" --ignore-not-found

echo "⏳ Aguardando terminação dos Pods..."
kubectl wait --for=delete pod --all -n media --timeout=120s 2>/dev/null || true

# 2. Remover Volumes (01-storage)
echo "🔻 Removendo Volumes (01-storage)..."
kubectl delete -f "${K8S_PATH}/01-storage/" --ignore-not-found

# 3. Remover Ingress Controller e Core (00-core)
echo "🔻 Removendo Traefik Ingress e Core (00-core)..."
helm uninstall traefik -n ingress-traefik 2>/dev/null || true
kubectl delete -f "${K8S_PATH}/00-core/" --ignore-not-found

# 4. Remover Namespaces Restantes
echo "🔻 Limpando Namespaces..."
kubectl delete namespace media ingress-traefik infra --ignore-not-found
kind delete cluster --name "${CLUSTER_NAME}"

echo "✨ Limpeza de resources concluída!"
