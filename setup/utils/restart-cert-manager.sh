#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

kubectl delete pod -n cert-manager -l app=cert-manager --context "kind-${CLUSTER_NAME}" >/dev/null
