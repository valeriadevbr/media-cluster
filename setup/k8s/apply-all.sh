#!/bin/bash
set -ea
source "$(dirname -- "$0")/../.env"
set +a

echo "Aplicando configurações. Raiz definida como: $SETUP_PATH"

K8S_DIR="$(dirname -- "$0")"

# Function to apply with envsubst
apply_with_subst() {
  local dir="$1"
  for file in "$dir"*.yaml; do
    [ -e "$file" ] || continue
    echo "Processing $file..."
    envsubst < "$file" | kubectl apply -f -
  done
}

apply_with_subst "${K8S_DIR}/00-core/"
apply_with_subst "${K8S_DIR}/01-storage/"
apply_with_subst "${K8S_DIR}/02-apps/"

echo "Tudo aplicado com sucesso."
