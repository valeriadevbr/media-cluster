#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

readonly BACKUP_FILE="${CONFIGS_PATH}/backups/wan-cert.yaml"

echo "Criando secret da CA Local para cert-manager..."
kubectl create secret tls local-ca-key-pair \
  --namespace cert-manager \
  --cert="${CERTS_PATH}/ca/ca.crt" \
  --key="${CERTS_PATH}/ca/ca.key" \
  --dry-run=client -o yaml | kubectl apply --context "kind-${INFRA_CLUSTER_NAME}" -f -

echo "Criando secret DYNU para cert-manager..."
kubectl create secret generic dynu-api-key-secret \
  --namespace cert-manager \
  --from-literal=api-key="$DYNU_API_KEY" \
  --dry-run=client -o yaml | kubectl apply --context "kind-${INFRA_CLUSTER_NAME}" -f -

if [ -f "$BACKUP_FILE" ]; then
  echo "♻️  Restaurando certificado WAN do backup (Infra)..."
  kubectl apply --context "kind-${INFRA_CLUSTER_NAME}" -f "$BACKUP_FILE"

  echo "♻️  Replicando certificado WAN do backup (Media)..."
  # O backup original está no namespace 'infra'. Ajustamos para 'media' antes de aplicar
  cat "$BACKUP_FILE" | sed 's/namespace: infra/namespace: media/' | kubectl apply --context "kind-${MEDIA_CLUSTER_NAME}" -f -
else
  echo "ℹ️  Nenhum backup de certificado WAN encontrado. O Cert-Manager irá gerar um novo no cluster INFRA."
fi
