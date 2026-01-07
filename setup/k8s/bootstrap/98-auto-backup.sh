#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
set +a

readonly BACKUP_FILE="${CONFIGS_PATH}/backups/wan-cert.yaml"
mkdir -p "$(dirname "$BACKUP_FILE")"

echo "⏳ [Auto-Backup] Aguardando certificado 'wan-wildcard-tls' ficar PRONTO para backup..."

# Se já existe backup restaurado, confiar nele e deixar o CronJob cuidar do futuro.
if [ -f "$BACKUP_FILE" ]; then
  echo "✅ [Auto-Backup] Backup já existe em '${BACKUP_FILE}'. Pulando espera inicial."
  exit 0
fi

echo "   Isso pode levar alguns minutos (Validação DNS)..."

# Loop de espera (Timeout de 10 minutos)
TIMEOUT=600
START_TIME=$(date +%s)

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

  if [ $ELAPSED_TIME -gt $TIMEOUT ]; then
    echo "⚠️  [Auto-Backup] Timeout aguardando certificado. O backup não foi gerado automaticamente."
    exit 0
  fi

  # Checa status Ready
  STATUS=$(kubectl get certificate wan-wildcard-tls -n infra --context "kind-${INFRA_CLUSTER_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

  if [ "$STATUS" == "True" ]; then
    echo "✅ [Auto-Backup] Certificado está PRONTO! Salvando..."

    kubectl get secret wan-wildcard-tls -n infra --context "kind-${INFRA_CLUSTER_NAME}" -o yaml |
      grep -v "creationTimestamp" |
      grep -v "resourceVersion" |
      grep -v "uid" |
      grep -v "ownerReferences" \
        >"${BACKUP_FILE}"

    echo "💾 [Auto-Backup] Backup salvo em: ${BACKUP_FILE}"
    break
  else
    echo -n "."
    sleep 10
  fi
done
