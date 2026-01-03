#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Instalando Traefik (HTTP/3 Enabled)..."

helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update traefik >/dev/null

subst_manifest "$(dirname "$0")/resources/traefik-values.yaml" |
  helm upgrade --install traefik traefik/traefik \
    --create-namespace \
    --namespace ingress-traefik \
    -f - \
    --wait >/dev/null

echo "Aguardando Traefik..."
kubectl rollout status deployment traefik -n ingress-traefik
