#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Instalando Traefik no Cluster INFRA (HTTP/3 Enabled)..."

# Instalar CRDs do Traefik v3.1
kubectl apply --context "${K8S_CONTEXT}" -f https://raw.githubusercontent.com/traefik/traefik/v3.1/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
kubectl apply --context "${K8S_CONTEXT}" -f https://raw.githubusercontent.com/traefik/traefik/v3.1/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml

helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update traefik >/dev/null

subst_manifest "$(dirname "$0")/resources/traefik-infra-values.yaml" |
  helm upgrade --install traefik traefik/traefik \
    --kube-context "${K8S_CONTEXT}" \
    --create-namespace \
    --namespace ingress-traefik-infra \
    -f - \
    --skip-crds \
    --wait >/dev/null

echo "Aguardando Traefik (Infra)..."
kubectl rollout status deployment traefik -n ingress-traefik-infra --context "${K8S_CONTEXT}"

echo "Traefik Infra pronto."
