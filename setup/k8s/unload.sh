#!/bin/bash
set -e
set -a
K8S_DIR="$(dirname -- "$0")"
source "${K8S_DIR}/../.env"
set +a

echo "🧹 Iniciando limpeza dos resources no cluster '${CLUSTER_NAME}'..."

# 1. Remover Apps (Sonarr, etc.)
echo "🔻 Removendo Aplicações (03-apps)..."
kubectl delete -f "${K8S_DIR}/03-apps/" --ignore-not-found

# 2. Remover Volumes (01-storage)
echo "🔻 Removendo Volumes (01-storage)..."
kubectl delete -f "${K8S_DIR}/01-storage/01-storage.yaml" --ignore-not-found

# 3. Remover Nginx Ingress e Core (00-core)
echo "🔻 Removendo Nginx Ingress e Core (00-core)..."
helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true
kubectl delete -f "${K8S_DIR}/00-core/" --ignore-not-found

# 4. Remover Namespaces Restantes
echo "🔻 Limpando Namespaces..."
kubectl delete namespace media ingress-nginx --ignore-not-found

echo "✨ Limpeza de resources concluída!"
echo "ℹ️  Nota: O cluster Kind '${CLUSTER_NAME}' continua rodando."
echo "   Para destruir tudo (reset total), rode: kind delete cluster --name ${CLUSTER_NAME}"
