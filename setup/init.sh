#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/.env"
set +a

"$SETUP_PATH/k8s/setup.sh"
"$SETUP_PATH/k8s/apply-all.sh"
"$SETUP_PATH/utils/set-pf-rules.sh"
