#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

helm repo add jetstack https://charts.jetstack.io >/dev/null
helm repo add cert-manager-dynu-webhook https://dopingus.github.io/cert-manager-webhook-dynu >/dev/null
helm repo update jetstack cert-manager-dynu-webhook >/dev/null

echo "Instalando cert-manager..."

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait >/dev/null

echo "Aguardando cert-manager..."
kubectl rollout status deployment cert-manager -n cert-manager

echo "Instalando cert-manager-webhook-dynu..."

helm upgrade --install cert-manager-dynu-webhook cert-manager-dynu-webhook/dynu-webhook \
  --namespace cert-manager \
  --set groupName=acme.dynu.com \
  --wait >/dev/null

echo "Aguardando webhook dynu..."
kubectl rollout status deployment cert-manager-dynu-webhook -n cert-manager
