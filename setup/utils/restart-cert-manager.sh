#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

kubectl delete pod -n cert-manager -l app=cert-manager --context "${K8S_CONTEXT}" >/dev/null
