#!/bin/bash
set -e
set -a
K8S_DIR="$(dirname -- "$0")"
source "${K8S_DIR}/../.env"
source "${SETUP_PATH}/utils/includes/k8s-utils.sh"
set +a

if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
  subst_manifest "${SETUP_PATH}/k8s/kind-config.yaml" | \
    kind create cluster --name "$CLUSTER_NAME" --image kindest/node:v1.31.1 --config -
fi

echo "🔧 Ajustando MTU diretamente no Node (Fix para HostNetwork/Traefik)..."
docker exec "$CLUSTER_NAME-control-plane" ip link set eth0 mtu 1400

kubectl create namespace ingress-traefik --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace media --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace infra --dry-run=client -o yaml | kubectl apply -f -

apply_with_subst "${K8S_DIR}/00-core/"
apply_with_subst "${K8S_DIR}/02-infra/02-test-connectivity.yaml"

kubectl create secret tls media-lan-tls \
  --cert="${CERTS_PATH}/lan/localhost.crt" \
  --key="${CERTS_PATH}/lan/localhost.key" \
  --namespace media \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls media-lan-tls \
  --cert="${CERTS_PATH}/lan/localhost.crt" \
  --key="${CERTS_PATH}/lan/localhost.key" \
  --namespace infra \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install traefik traefik/traefik \
  --namespace ingress-traefik \
  --create-namespace \
  --set ports.websecure.http3.enabled=true \
  --set providers.kubernetesIngress.enabled=true \
  --set service.type=ClusterIP \
  --set hostNetwork=true \
  --set dnsPolicy=ClusterFirstWithHostNet \
  --set "additionalArguments={ \
    --entryPoints.web.address=:80, \
    --entryPoints.websecure.address=:443, \
    --entryPoints.websecure.http3, \
    --serverstransport.insecureskipverify=true, \
    --log.level=DEBUG \
  }" \
  --set ports.web.port=80 \
  --set ports.websecure.port=443 \
  --set deployment.podSecurityContext.runAsNonRoot=true \
  --set deployment.podSecurityContext.runAsUser=65532 \
  --set deployment.podSecurityContext.runAsGroup=65532 \
  --set "deployment.securityContext.capabilities.add={NET_BIND_SERVICE}" > /dev/null

kubectl rollout status deployment traefik -n ingress-traefik
