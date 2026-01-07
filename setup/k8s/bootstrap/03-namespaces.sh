#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
set +a

kubectl create namespace media --dry-run=client -o yaml | kubectl apply --context "kind-${MEDIA_CLUSTER_NAME}" -f -
kubectl create namespace infra --dry-run=client -o yaml | kubectl apply --context "kind-${INFRA_CLUSTER_NAME}" -f -
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply --context "kind-${INFRA_CLUSTER_NAME}" -f -
