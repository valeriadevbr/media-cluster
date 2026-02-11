#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

helm repo add emberstack https://emberstack.github.io/helm-charts >/dev/null
helm repo update emberstack >/dev/null

echo "Instalando Kubernetes Reflector..."

helm upgrade --install reflector emberstack/reflector \
  --kube-context "${K8S_CONTEXT}" \
  --namespace ingress-traefik-infra \
  --wait >/dev/null

echo "Aguardando reflector..."
kubectl rollout status deployment reflector -n ingress-traefik-infra --context "${K8S_CONTEXT}"
