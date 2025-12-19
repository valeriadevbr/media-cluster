#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
source "${SETUP_PATH}/utils/includes/k8s-utils.sh"
HOMEBREW_NO_ENV_HINTS=1
HOMEBREW_NO_AUTO_UPDATE=1
set +a

# 1. Verifica e Instala Kind/Helm/Kubectl
if ! command -v kind &>/dev/null; then
  echo "Instalando Kind..."
  brew install kind -q
fi
if ! command -v helm &>/dev/null; then
  echo "Instalando Helm..."
  brew install helm -q
fi
if ! command -v kubectl &>/dev/null; then
  echo "Instalando Kubectl..."
  brew install kubectl -q
fi

# 2. Cria Cluster Kind
if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
  echo "Criando cluster Kind '$CLUSTER_NAME'..."
  subst_manifest "${SETUP_PATH}/k8s/kind-config.yaml" | \
    kind create cluster --name "$CLUSTER_NAME" --image kindest/node:v1.31.1 --config -

  echo "🔧 Ajustando MTU diretamente no Node e Desativando Offloads (Fix para HostNetwork/Traefik)..."
  docker exec "$CLUSTER_NAME-control-plane" ip link set eth0 mtu 1400
  docker exec "$CLUSTER_NAME-control-plane" ethtool -K eth0 tso off gso off || true
else
  echo "Selecionando '$CLUSTER_NAME' existente..."
  kubectl config use-context "kind-$CLUSTER_NAME"
fi

# 3 Build e Carrega Imagens Personalizadas
echo "Building Sonarr custom image..."
docker build -t "$SONARR_IMAGE_NAME" -f "$SONARR_DOCKERFILE_PATH" "$DOCKER_BUILD_CONTEXT" > /dev/null
echo "Loading Sonarr image into Kind..."
kind load docker-image "$SONARR_IMAGE_NAME" --name "$CLUSTER_NAME" > /dev/null

echo "Building Radarr custom image..."
docker build -t "$RADARR_IMAGE_NAME" -f "$RADARR_DOCKERFILE_PATH" "$DOCKER_BUILD_CONTEXT" > /dev/null
echo "Loading Radarr image into Kind..."
kind load docker-image "$RADARR_IMAGE_NAME" --name "$CLUSTER_NAME" > /dev/null

# 4. Adiciona repositórios Helm
helm repo add traefik https://traefik.github.io/charts > /dev/null
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/ > /dev/null
helm repo update > /dev/null

# 5. Cria os Namespaces base
kubectl create namespace ingress-traefik --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace media --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace infra --dry-run=client -o yaml | kubectl apply -f -

# 6. Cria os Segredos TLS
echo "Criando secret TLS..."

kubectl create secret tls media-lan-tls \
  --cert="${CERTS_PATH}/lan/localhost.crt" \
  --key="${CERTS_PATH}/lan/localhost.key" \
  --namespace media \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls media-wan-tls \
  --cert="${CERTS_PATH}/wan/apedamo.duckdns.org.crt" \
  --key="${CERTS_PATH}/wan/apedamo.duckdns.org.key" \
  --namespace media \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls media-lan-tls \
  --cert="${CERTS_PATH}/lan/localhost.crt" \
  --key="${CERTS_PATH}/lan/localhost.key" \
  --namespace infra \
  --dry-run=client -o yaml | kubectl apply -f -

# 7. Instala o Traefik Ingress Controller
echo "Instalando Traefik (HTTP/3 Enabled)..."

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
  --set "deployment.securityContext.capabilities.add={NET_BIND_SERVICE}" >/dev/null

echo "Aguardando Traefik..."
kubectl rollout status deployment traefik -n ingress-traefik

# 8. Instala Metrics Server (Necessário para Resource Limits)
echo "Instalando Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml >/dev/null
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' >/dev/null

echo "Setup concluído!"
