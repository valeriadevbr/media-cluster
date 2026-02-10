#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
source "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

CLUSTER_NAME="$CLUSTER_NAME"
CONTEXT="kind-${CLUSTER_NAME}"
BASE_PATH="${K8S_PATH}/media"

echo "--------------------------------------------------"
echo "🧹 Iniciando limpeza do contexto MEDIA"
echo "--------------------------------------------------"

if ! kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1; then
  echo "⚠️  Contexto '$CONTEXT' não encontrado."
else
  if [ -d "${BASE_PATH}/03-apps" ]; then
    echo "🔻 Removendo Apps (Media)..."
    kubectl delete -f "${BASE_PATH}/03-apps/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/02-ingress" ]; then
    echo "🔻 Removendo Ingress (Media)..."
    kubectl delete -f "${BASE_PATH}/02-ingress/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/01-storage" ]; then
    echo "🔻 Removendo Storage (Media)..."
    kubectl delete -f "${BASE_PATH}/01-storage/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/00-core" ]; then
    echo "🔻 Removendo Core (Media)..."
    kubectl delete -f "${BASE_PATH}/00-core/" --context="$CONTEXT" --ignore-not-found
  fi

  echo "🔻 Removendo Namespace 'media'..."
  kubectl delete namespace media --context="$CONTEXT" --ignore-not-found
fi

echo "✅ Limpeza de Media concluída (Cluster mantido)."
