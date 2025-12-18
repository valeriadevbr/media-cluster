#!/bin/bash
set -ea
source "$(dirname -- "$0")/.env"
set +a

echo "🔥 Destruindo cluster Kind '${CLUSTER_NAME}' (Reset Total)..."
kind delete cluster --name "${CLUSTER_NAME}"
