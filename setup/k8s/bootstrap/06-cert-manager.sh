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
  --kube-context "kind-${INFRA_CLUSTER_NAME}" \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set extraArgs[0]="--dns01-recursive-nameservers=162.216.242.2:53\,108.181.13.234:53" \
  --set extraArgs[1]="--dns01-recursive-nameservers-only=true" \
  --wait >/dev/null

echo "Aguardando cert-manager..."
kubectl rollout status deployment cert-manager -n cert-manager --context "kind-${INFRA_CLUSTER_NAME}"

echo "Instalando cert-manager-webhook-dynu..."

helm upgrade --install cert-manager-dynu-webhook cert-manager-dynu-webhook/dynu-webhook \
  --kube-context "kind-${INFRA_CLUSTER_NAME}" \
  --namespace cert-manager \
  --set groupName=acme.dynu.com \
  --wait >/dev/null

echo "Aguardando webhook dynu..."
kubectl rollout status deployment cert-manager-dynu-webhook -n cert-manager --context "kind-${INFRA_CLUSTER_NAME}"
