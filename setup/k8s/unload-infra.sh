#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
source "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

CLUSTER_NAME="$INFRA_CLUSTER_NAME"
CONTEXT="kind-${CLUSTER_NAME}"
BASE_PATH="${K8S_PATH}/infra"

echo "--------------------------------------------------"
echo "🧹 Iniciando limpeza do cluster '${CLUSTER_NAME}'"
echo "--------------------------------------------------"

if ! kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1; then
  echo "⚠️  Contexto '$CONTEXT' não encontrado. O cluster já pode ter sido deletado."
else
  if [ -d "${BASE_PATH}/03-apps" ]; then
    echo "🔻 Removendo Apps (DNS)..."
    kubectl delete -f "${BASE_PATH}/03-apps/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/01-storage" ]; then
    echo "🔻 Removendo Storage..."
    kubectl delete -f "${BASE_PATH}/01-storage/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/00-core" ]; then
    echo "🔻 Removendo Core..."
    kubectl delete -f "${BASE_PATH}/00-core/" --context="$CONTEXT" --ignore-not-found
  fi

  echo "🔻 Removendo Namespaces..."
  kubectl delete namespace infra --context="$CONTEXT" --ignore-not-found
fi

echo "🔥 Deletando Cluster Kind Infra..."
kind delete cluster --name "${CLUSTER_NAME}"
