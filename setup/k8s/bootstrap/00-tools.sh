#!/bin/bash
set -e

OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
  set -a
  HOMEBREW_NO_ENV_HINTS=1
  HOMEBREW_NO_AUTO_UPDATE=1
  set +a
fi

# Instalar Kind
if ! command -v kind &>/dev/null; then
  echo "Instalando Kind..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kind -q
  fi
fi

# Instalar Helm
if ! command -v helm &>/dev/null; then
  echo "Instalando Helm..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install helm -q
  fi
fi

# Instalar Kubectl
if ! command -v kubectl &>/dev/null; then
  echo "Instalando Kubectl..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kubectl -q
  fi
fi
