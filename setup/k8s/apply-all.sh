#!/bin/bash
set -e
set -a
K8S_DIR="$(dirname -- "$0")"
source "${K8S_DIR}/../.env"
source "${SETUP_PATH}/includes/k8s-utils.sh"
set +a

echo "Aplicando configurações. Raiz definida como: $SETUP_PATH"

# 1. Core e Storage
apply_with_subst "${K8S_DIR}/00-core/"
apply_with_subst "${K8S_DIR}/01-storage/"

# 2. Infraestrutura (DNS, Ingress, etc)
echo "🌐 Aplicando e aguardando infraestrutura (DNS)..."
apply_with_subst "${K8S_DIR}/02-infra/"
kubectl rollout status deployment/dns -n infra --timeout=60s

# 3. Apps Prioritários (Plex/Emby)
echo "🚀 Aplicando e aguardando apps prioritários (Plex/Emby)..."
apply_with_subst "${K8S_DIR}/03-apps/03-plex.yaml"
apply_with_subst "${K8S_DIR}/03-apps/03-emby.yaml"
kubectl rollout status deployment/plex -n media --timeout=120s
kubectl rollout status deployment/emby -n media --timeout=120s

# 4. Restante das aplicações
echo "📦 Aplicando restante das aplicações..."
apply_with_subst "${K8S_DIR}/03-apps/"

echo "Tudo aplicado com sucesso."
