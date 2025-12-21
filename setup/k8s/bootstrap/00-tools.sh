#!/bin/bash
set -e
set -a
HOMEBREW_NO_ENV_HINTS=1
HOMEBREW_NO_AUTO_UPDATE=1
set +a

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
