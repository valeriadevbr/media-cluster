#!/bin/bash
set -e

echo "Instalando Traefik (HTTP/3 Enabled)..."

helm repo add traefik https://traefik.github.io/charts >/dev/null
helm repo update traefik >/dev/null

helm upgrade --install traefik traefik/traefik \
  --namespace ingress-traefik \
  --create-namespace \
  --set "providers.kubernetesIngress.enabled=true" \
  --set "service.type=NodePort" \
  --set "additionalArguments={--serverstransport.insecureskipverify=true}" \
  --set "ports.web.middlewares[0]=ingress-traefik-gzip@kubernetescrd" \
  --set "ports.web.nodePort=80" \
  --set "ports.web-wan.expose.default=true" \
  --set "ports.web-wan.middlewares[0]=ingress-traefik-gzip@kubernetescrd" \
  --set "ports.web-wan.port=44000" \
  --set "ports.web-wan.exposedPort=44000" \
  --set "ports.web-wan.nodePort=44000" \
  --set "ports.websecure.http3.enabled=true" \
  --set "ports.websecure.middlewares[0]=ingress-traefik-gzip@kubernetescrd" \
  --set "ports.websecure.nodePort=443" \
  --set "ports.websecure-wan.expose.default=true" \
  --set "ports.websecure-wan.http3.enabled=true" \
  --set "ports.websecure-wan.middlewares[0]=ingress-traefik-gzip@kubernetescrd" \
  --set "ports.websecure-wan.port=44300" \
  --set "ports.websecure-wan.exposedPort=44300" \
  --set "ports.websecure-wan.nodePort=44300" \
  --set "ports.websecure-wan.tls.enabled=true" \
  --set "deployment.podSecurityContext.runAsNonRoot=true" \
  --set "deployment.podSecurityContext.runAsUser=65532" \
  --set "deployment.podSecurityContext.runAsGroup=65532" \
  --set "deployment.securityContext.capabilities.add={NET_BIND_SERVICE}" \
  --wait >/dev/null

echo "Aguardando Traefik..."
kubectl rollout status deployment traefik -n ingress-traefik
