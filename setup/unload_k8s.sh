#!/bin/bash
set -ea
source "$(dirname -- "$0")/.env"
set +a

"$SETUP_PATH/k8s/unload.sh"
