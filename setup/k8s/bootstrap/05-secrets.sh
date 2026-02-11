#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

readonly BACKUP_FILE="${CONFIGS_PATH}/backups/wan-cert.yaml"
readonly TSIG_KEYS_FILE="${CONFIGS_PATH}/bind/config/named.conf.externaldns-key"
readonly SECRET_NAME="wan-wildcard-tls"

# NOTE: The CA secret 'local-ca-key-pair' should be managed by cert-manager using a SelfSigned issuer
# if we want to avoid manual SSL folder dependencies.
# kubectl create secret tls local-ca-key-pair \
#   --namespace cert-manager \
#   --cert="${CERTS_PATH}/ca/ca.crt" \
#   --key="${CERTS_PATH}/ca/ca.key" \
#   --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -

echo "Criando secret DYNU para cert-manager..."
kubectl create secret generic dynu-api-key-secret \
  --namespace cert-manager \
  --from-literal=api-key="$DYNU_API_KEY" \
  --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -

if [ -s "$TSIG_KEYS_FILE" ]; then
  TSIG_SECRET_VALUE=$(grep 'secret "' "$TSIG_KEYS_FILE" | sed -E 's/.*secret "(.*)";/\1/')
  if [ -n "$TSIG_SECRET_VALUE" ]; then
    echo "🔑 Criando secret TSIG para ExternalDNS (Infra)..."
    kubectl create secret generic rfc2136-tsig-secret \
      --namespace infra \
      --from-literal=tsig-secret="$TSIG_SECRET_VALUE" \
      --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -

    echo "🔑 Criando secret TSIG para ExternalDNS (Media)..."
    kubectl create secret generic rfc2136-tsig-secret \
      --namespace media \
      --from-literal=tsig-secret="$TSIG_SECRET_VALUE" \
      --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -
  else
    echo "⚠️  Não foi possível extrair a secret do arquivo $TSIG_KEYS_FILE."
  fi
else
  echo "⚠️  Arquivo de chaves TSIG não encontrado ($TSIG_KEYS_FILE). Certifique-se de rodar 04-bind-keys.sh primeiro."
fi

if [ -f "$BACKUP_FILE" ]; then
  echo "♻️  Restaurando certificado WAN do backup (Infra)..."
  kubectl apply --context "${K8S_CONTEXT}" -f "$BACKUP_FILE"

  # Add reflector annotations to enable automatic sync later
  kubectl annotate secret "$SECRET_NAME" -n infra \
    reflector.emberstack.com/reflection-allowed="true" \
    reflector.emberstack.com/reflection-allowed-namespaces="media" \
    reflector.emberstack.com/reflection-auto="true" \
    reflector.emberstack.com/reflection-auto-namespaces="media" \
    --overwrite --context "${K8S_CONTEXT}"

  echo "♻️  Replicando certificado WAN do backup (Media)..."
  cat "$BACKUP_FILE" | sed 's/namespace: infra/namespace: media/' | kubectl apply --context "${K8S_CONTEXT}" -f -
else
  echo "ℹ️  Nenhum backup de certificado WAN encontrado. O Cert-Manager irá gerar um novo no cluster INFRA."
fi
