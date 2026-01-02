#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/.env"
set +a

"$SETUP_PATH/k8s/unload-media.sh"
