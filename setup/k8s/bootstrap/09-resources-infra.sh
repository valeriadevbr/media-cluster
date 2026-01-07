#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
set +a

echo "📦 Aplicando recursos do Cluster Infra (Ingress/Apps)..."
"${K8S_PATH}/apply-infra.sh"
