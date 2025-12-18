#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
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
  envsubst <"$(dirname -- "$0")/kind-config.yaml" | kind create cluster --name "$CLUSTER_NAME" --config -

  echo "Ajustando MTU do cluster (Otimizado para WAN/VPN/PPPoE)..."
  kubectl patch daemonset kindnet -n kube-system --type='json' -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/env/-",
      "value": {
        "name": "MTU",
        "value": "1280"
      }
    }
  ]'
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

# 4. Adiciona repositório do Nginx Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx > /dev/null
helm repo update > /dev/null

# 5. Cria os Namespaces base
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace media --dry-run=client -o yaml | kubectl apply -f -

# 6. Cria o Segredo TLS
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

# 7. Instala o Controlador Nginx
echo "Instalando Nginx Ingress Controller..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=ClusterIP \
  --set controller.hostNetwork=true \
  --set controller.dnsPolicy=ClusterFirstWithHostNet \
  --set controller.reportNodeInternalIpAddress=true \
  --set controller.kind=DaemonSet \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.config.use-forwarded-headers="true" \
  --set controller.config.compute-full-forwarded-for="true" >/dev/null

echo "Aguardando Nginx..."
kubectl rollout status daemonset ingress-nginx-controller -n ingress-nginx

echo "Setup concluído!"
