#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Instalando Traefik no Cluster MEDIA (HTTP/3 Enabled)..."

helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update traefik >/dev/null

subst_manifest "$(dirname "$0")/resources/traefik-media-values.yaml" |
  helm upgrade --install traefik traefik/traefik \
    --kube-context "${K8S_CONTEXT}" \
    --create-namespace \
    --namespace ingress-traefik-media \
    -f - \
    --skip-crds \
    --wait >/dev/null

echo "Aguardando Traefik (Media)..."
kubectl rollout status deployment traefik -n ingress-traefik-media --context "${K8S_CONTEXT}"

echo "Traefik Media pronto."
