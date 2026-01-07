#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

kubectl delete pod -n cert-manager -l app=cert-manager --context "kind-${INFRA_CLUSTER_NAME}" >/dev/null
