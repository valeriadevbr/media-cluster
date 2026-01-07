#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
set +a

echo "📦 Aplicando recursos do Cluster Media (Ingress/Apps)..."
"${K8S_PATH}/apply-media.sh"
