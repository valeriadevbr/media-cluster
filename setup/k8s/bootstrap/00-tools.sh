#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../includes/load-env.sh"
. "$(dirname -- "$0")/../../includes/pkg-utils.sh"
set +a

if ! command -v curl &>/dev/null; then
  echo "Instalando Curl..."
  install_sys_pkg "curl"
fi

if ! command -v envsubst &>/dev/null; then
  echo "Instalando Gettext (envsubst)..."
  install_sys_pkg "gettext"
fi

if ! command -v yq &>/dev/null; then
  echo "Instalando yq..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install yq -q
  else
    sudo curl -L https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 -o /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
  fi
fi

if ! command -v kind &>/dev/null; then
  echo "Instalando Kind..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kind -q
  else
    sudo curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
    sudo chmod +x /usr/local/bin/kind
  fi
fi

if ! command -v helm &>/dev/null; then
  echo "Instalando Helm..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install helm -q
  else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    sudo chmod +x /usr/local/bin/helm
  fi
fi

if ! command -v kubectl &>/dev/null; then
  echo "Instalando Kubectl..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kubectl -q
  else
    sudo curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo chmod +x /usr/local/bin/kubectl
  fi
fi
