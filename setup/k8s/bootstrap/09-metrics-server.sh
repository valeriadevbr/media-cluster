#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
set +a

# Lista de contextos para iterar
CONTEXT="kind-${CLUSTER_NAME}"

echo "Instalando Metrics Server no contexto: $CONTEXT..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --context "$CONTEXT" >/dev/null
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' --context "$CONTEXT" >/dev/null
echo "✓ Metrics Server instalado com sucesso no contexto: $CONTEXT"

echo "✓ Metrics Server instalado em todos os clusters"
