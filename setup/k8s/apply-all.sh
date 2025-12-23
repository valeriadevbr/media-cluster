#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
source "${SETUP_PATH}/includes/k8s-utils.sh"
set +a

echo "Aplicando configurações. Raiz definida como: $SETUP_PATH"

# 1. Core e Storage
apply_with_subst "${K8S_PATH}/00-core/"
apply_with_subst "${K8S_PATH}/01-storage/"

# 2. Infraestrutura (DNS, Ingress, etc)
echo "🌐 Aplicando e aguardando infraestrutura (DNS)..."
apply_with_subst "${K8S_PATH}/02-infra/"
kubectl rollout status deployment/dns -n infra --timeout=60s

# 3. Apps Prioritários (Plex/Emby)
echo "🚀 Aplicando e aguardando apps prioritários (Plex/Emby)..."
apply_with_subst "${K8S_PATH}/03-apps/01-plex.yaml"
apply_with_subst "${K8S_PATH}/03-apps/02-emby.yaml"
kubectl rollout status deployment/plex -n media --timeout=120s
kubectl rollout status deployment/emby -n media --timeout=120s

# 4. Restante das aplicações
echo "📦 Aplicando restante das aplicações..."
apply_with_subst "${K8S_PATH}/03-apps/"

echo "Tudo aplicado com sucesso."
