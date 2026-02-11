#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/k8s-utils.sh"
set +a

if ! kubectl config get-contexts "${K8S_CONTEXT}" >/dev/null 2>&1; then
  echo "❌ Erro: O contexto Kubernetes '${K8S_CONTEXT}' não foi encontrado."
  echo "Certifique-se de que o OrbStack está rodando ou que o contexto está configurado corretamente."
  exit 1
fi

if [[ "$K8S_CONTEXT" == "orbstack" ]]; then
  echo "Utilizando contexto OrbStack: $K8S_CONTEXT."
  echo "🔧 Ajustando configurações de rede no OrbStack..."

  # Apply sysctls via a privileged pod
  kubectl run sysctl-patch --image=busybox --privileged --restart=Never \
    --overrides='{"spec": {"hostNetwork": true}}' \
    --context "${K8S_CONTEXT}" \
    -- sh -c "sysctl -w net.core.rmem_max=16777216 net.core.wmem_max=16777216 net.ipv4.tcp_rmem='4096 87380 16777216' net.ipv4.tcp_wmem='4096 65536 16777216' net.ipv4.ip_unprivileged_port_start=0" >/dev/null

  # Wait for it to complete and cleanup
  sleep 5
  kubectl delete pod sysctl-patch --context "${K8S_CONTEXT}" --ignore-not-found >/dev/null
else
  echo "Utilizando contexto '${K8S_CONTEXT}'..."
fi

echo "✅ Cluster Unificado pronto."
