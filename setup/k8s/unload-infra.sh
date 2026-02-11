#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
source "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

CONTEXT="${K8S_CONTEXT}"
BASE_PATH="${K8S_PATH}/infra"

echo "--------------------------------------------------"
echo "🧹 Iniciando limpeza do contexto INFRA"
echo "--------------------------------------------------"

if ! kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1; then
  echo "⚠️  Contexto '$CONTEXT' não encontrado."
else
  if [ -d "${BASE_PATH}/03-apps" ]; then
    echo "🔻 Removendo Apps (Infra)..."
    kubectl delete -f "${BASE_PATH}/03-apps/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/02-ingress" ]; then
    echo "🔻 Removendo Ingress (Infra)..."
    kubectl delete -f "${BASE_PATH}/02-ingress/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/01-storage" ]; then
    echo "🔻 Removendo Storage (Infra)..."
    kubectl delete -f "${BASE_PATH}/01-storage/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/00-core" ]; then
    echo "🔻 Removendo Core (Infra)..."
    kubectl delete -f "${BASE_PATH}/00-core/" --context="$CONTEXT" --ignore-not-found
  fi

  echo "🔻 Removendo Namespace 'infra'..."
  kubectl delete namespace infra --context="$CONTEXT" --ignore-not-found
fi

echo "✅ Limpeza de Infra concluída (Cluster mantido)."
