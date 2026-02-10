#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Instalando Traefik no Cluster INFRA (HTTP/3 Enabled)..."

helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update traefik >/dev/null

subst_manifest "$(dirname "$0")/resources/traefik-infra-values.yaml" |
  helm upgrade --install traefik traefik/traefik \
    --kube-context "kind-${CLUSTER_NAME}" \
    --create-namespace \
    --namespace ingress-traefik-infra \
    -f - \
    --wait >/dev/null

echo "Aguardando Traefik (Infra)..."
kubectl rollout status deployment traefik -n ingress-traefik-infra --context "kind-${CLUSTER_NAME}"

echo "Traefik Infra pronto."
