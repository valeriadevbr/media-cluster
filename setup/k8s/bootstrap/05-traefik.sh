#!/bin/bash
set -e

echo "Instalando Traefik (HTTP/3 Enabled)..."

helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update traefik >/dev/null

helm upgrade --install traefik traefik/traefik \
  --namespace ingress-traefik \
  --create-namespace \
  --set ports.websecure.http3.enabled=true \
  --set providers.kubernetesIngress.enabled=true \
  --set service.type=NodePort \
  --set "additionalArguments={--serverstransport.insecureskipverify=true}" \
  --set ports.web.nodePort=80 \
  --set ports.websecure.nodePort=443 \
  --set ports.websecure-alt.port=44300 \
  --set ports.websecure-alt.exposedPort=44300 \
  --set ports.websecure-alt.nodePort=44300 \
  --set deployment.podSecurityContext.runAsNonRoot=true \
  --set deployment.podSecurityContext.runAsUser=65532 \
  --set deployment.podSecurityContext.runAsGroup=65532 \
  --set "deployment.securityContext.capabilities.add={NET_BIND_SERVICE}" \
  --wait >/dev/null

echo "Aguardando Traefik..."
kubectl rollout status deployment traefik -n ingress-traefik
