#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Criando secret da CA Local para cert-manager..."
kubectl create secret tls local-ca-key-pair \
  --namespace cert-manager \
  --cert="${CERTS_PATH}/ca/ca.crt" \
  --key="${CERTS_PATH}/ca/ca.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Criando secret DYNU para cert-manager..."
kubectl create secret generic dynu-api-key-secret \
  --namespace cert-manager \
  --from-literal=api-key="$DYNU_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
