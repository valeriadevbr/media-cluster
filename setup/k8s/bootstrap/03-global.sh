#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

echo "Aplicando recursos globais..."

echo "📝 Aplicando CoreDNS Patch..."
apply_k8s_file "${K8S_PATH}/global/00-coredns-patch.yaml" "$K8S_CONTEXT"
kubectl rollout restart deployment coredns -n kube-system --context="${K8S_CONTEXT}"
kubectl rollout status deployment coredns -n kube-system --context="${K8S_CONTEXT}"

echo "🌍 Aplicando ExternalDNS Global..."
apply_k8s_file "${K8S_PATH}/global/01-external-dns.yaml" "$K8S_CONTEXT"

echo "✅ Recursos globais aplicados com sucesso."
