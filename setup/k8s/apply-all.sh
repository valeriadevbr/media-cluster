#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
set +a

echo "Aplicando configurações. Raiz definida como: $SETUP_PATH"

K8S_DIR="$(dirname -- "$0")"

# Function to apply with envsubst
apply_with_subst() {
  local dir="$1"
  for file in "$dir"*.yaml; do
    [ -e "$file" ] || continue
    echo "Processing $file..."
    envsubst < "$file" | kubectl apply -f -
  done
}

apply_with_subst "${K8S_DIR}/00-core/"
apply_with_subst "${K8S_DIR}/01-storage/"
apply_with_subst "${K8S_DIR}/02-infra/"

# 1. Prioridade Máxima: DNS (BIND)
echo "🌐 Aplicando e aguardando infraestrutura crítica (DNS)..."
envsubst < "${K8S_DIR}/02-infra/02-bind.yaml" | kubectl apply -f -
kubectl rollout status deployment/dns -n media --timeout=60s

# 2. Prioridade: Plex e Emby
echo "🚀 Aplicando e aguardando apps prioritários (Plex/Emby)..."
envsubst < "${K8S_DIR}/03-apps/03-plex.yaml" | kubectl apply -f -
envsubst < "${K8S_DIR}/03-apps/03-emby.yaml" | kubectl apply -f -
kubectl rollout status deployment/plex -n media --timeout=120s
kubectl rollout status deployment/emby -n media --timeout=120s

# 3. Restante das aplicações
echo "📦 Aplicando restante das aplicações..."
apply_with_subst "${K8S_DIR}/03-apps/"

echo "Tudo aplicado com sucesso."
