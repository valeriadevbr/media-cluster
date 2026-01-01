#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
set +a

if [[ "$OS" == "Darwin" ]]; then
  set -a
  HOMEBREW_NO_ENV_HINTS=1
  HOMEBREW_NO_AUTO_UPDATE=1
  set +a
fi

# Instalar yq
if ! command -v yq &>/dev/null; then
  echo "Instalando yq..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install yq -q
  else
    curl -L https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 -o /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
  fi
fi

# Instalar Kind
if ! command -v kind &>/dev/null; then
  echo "Instalando Kind..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kind -q
  else
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
  fi
fi

# Instalar Helm
if ! command -v helm &>/dev/null; then
  echo "Instalando Helm..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install helm -q
  else
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
  fi
fi

# Instalar Kubectl
if ! command -v kubectl &>/dev/null; then
  echo "Instalando Kubectl..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kubectl -q
  else
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
  fi
fi
