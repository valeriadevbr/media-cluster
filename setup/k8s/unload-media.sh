#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
source "$(dirname -- "$0")/../includes/k8s-utils.sh"
set +a

CLUSTER_NAME="$MEDIA_CLUSTER_NAME"
CONTEXT="kind-${CLUSTER_NAME}"
BASE_PATH="${K8S_PATH}/media"

echo "--------------------------------------------------"
echo "🧹 Iniciando limpeza do cluster '${CLUSTER_NAME}'"
echo "--------------------------------------------------"

if ! kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1; then
  echo "⚠️  Contexto '$CONTEXT' não encontrado. O cluster já pode ter sido deletado."
else
  if [ -d "${BASE_PATH}/03-apps" ]; then
    echo "🔻 Removendo Apps..."
    kubectl delete -f "${BASE_PATH}/03-apps/" --context="$CONTEXT" --ignore-not-found
  fi

  if [ -d "${BASE_PATH}/02-ingress" ]; then
    echo "🔻 Removendo Ingress..."
    kubectl delete -f "${BASE_PATH}/02-ingress/" --context="$CONTEXT" --ignore-not-found
  fi

  if helm status traefik -n ingress-traefik --kube-context="$CONTEXT" >/dev/null 2>&1; then
    echo "🔻 Desinstalando Traefik (Helm)..."
    helm uninstall traefik -n ingress-traefik --kube-context="$CONTEXT" 2>/dev/null || true
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
  kubectl delete namespace media infra ingress-traefik --context="$CONTEXT" --ignore-not-found
fi

echo "🔥 Deletando Cluster Kind Media..."
kind delete cluster --name "${CLUSTER_NAME}"
