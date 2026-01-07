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
    --kube-context "kind-${MEDIA_CLUSTER_NAME}" \
    --create-namespace \
    --namespace ingress-traefik \
    -f - \
    --wait >/dev/null

echo "Aguardando Traefik (Media)..."
kubectl rollout status deployment traefik -n ingress-traefik --context "kind-${MEDIA_CLUSTER_NAME}"

# Descoberta dinâmica do IP do cluster Media para roteamento inter-cluster
export MEDIA_CLUSTER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${MEDIA_CLUSTER_NAME}-control-plane")
echo "🔗 IP do Cluster Media detectado: ${MEDIA_CLUSTER_IP}"

echo "🔧 Patching Traefik HostAliases..."
kubectl patch deployment traefik -n ingress-traefik --context "kind-${INFRA_CLUSTER_NAME}" \
  --type='json' \
  -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/hostAliases\", \"value\": [{\"ip\": \"${MEDIA_CLUSTER_IP}\", \"hostnames\": [\"media-cluster-control-plane\"]}]}]" || echo "HostAliases patch failed (maybe already applied?)"

echo "Traefik Media pronto."
