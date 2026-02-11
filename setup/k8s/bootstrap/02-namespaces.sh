#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
set +a

kubectl create namespace media --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -
kubectl create namespace infra --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -
kubectl create namespace smarthome --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -
kubectl create namespace ingress-traefik-infra --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -
kubectl create namespace ingress-traefik-media --dry-run=client -o yaml | kubectl apply --context "${K8S_CONTEXT}" -f -
