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
  --set service.type=ClusterIP \
  --set hostNetwork=true \
  --set dnsPolicy=ClusterFirstWithHostNet \
  --set "additionalArguments={ \
    --entryPoints.web.address=:80, \
    --entryPoints.websecure.address=:443, \
    --entryPoints.websecure.http3, \
    --entryPoints.websecure-alt.address=:44300, \
    --serverstransport.insecureskipverify=true, \
    --log.level=INFO \
  }" \
  --set ports.web.port=80 \
  --set ports.websecure.port=443 \
  --set ports.websecure-alt.port=44300 \
  --set ports.websecure-alt.protocol=TCP \
  --set ports.websecure-alt.exposedPort=44300 \
  --set deployment.podSecurityContext.runAsNonRoot=true \
  --set deployment.podSecurityContext.runAsUser=65532 \
  --set deployment.podSecurityContext.runAsGroup=65532 \
  --set "deployment.securityContext.capabilities.add={NET_BIND_SERVICE}" >/dev/null

echo "Aguardando Traefik..."
kubectl rollout status deployment traefik -n ingress-traefik
