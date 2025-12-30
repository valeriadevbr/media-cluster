#!/bin/bash
set -e

echo "Instalando Traefik (HTTP/3 Enabled)..."

helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update traefik >/dev/null

helm upgrade --install traefik traefik/traefik \
  --create-namespace \
  --namespace ingress-traefik \
  -f "$(dirname "$0")/resources/traefik-values.yaml" \
  --wait >/dev/null

echo "Aguardando Traefik..."
kubectl rollout status deployment traefik -n ingress-traefik
