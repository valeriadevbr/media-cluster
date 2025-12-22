#!/bin/bash
set -e

# Get the directory of the script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$DIR/../../.env" ]; then
  set -a
  source "$DIR/../../.env"
  set +a
fi

OUTPUT_FILE="${K8S_PATH}/02-infra/99-monitoring.yaml"

echo "Generating monitoring manifest..."

# Update repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update prometheus-community >/dev/null

# Check for Grafana credentials
if [ -z "$GRAFANA_USER" ] || [ -z "$GRAFANA_PASSWORD" ]; then
  echo "❌ GRAFANA_USER and GRAFANA_PASSWORD must be set in .env"
  exit 1
fi

# Template chart
helm template monitoring prometheus-community/kube-prometheus-stack \
  --namespace infra \
  --version 66.3.0 \
  --include-crds \
  --create-namespace \
  -f "${CONFIGS_PATH}/grafana/values.yaml" \
  --set grafana.adminUser="$GRAFANA_USER" \
  --set grafana.adminPassword="$GRAFANA_PASSWORD" \
  > "${OUTPUT_FILE}.tmp"

echo "Splitting CRDs..."
python3 "${SETUP_PATH}/utils/split_manifest.py" "${OUTPUT_FILE}.tmp" "${K8S_PATH}/02-infra/99-monitoring-crds.yaml" "${OUTPUT_FILE}"
rm "${OUTPUT_FILE}.tmp"

echo "Manifests generated:"
echo " - ${K8S_PATH}/02-infra/99-monitoring-crds.yaml"
echo " - ${OUTPUT_FILE}"
