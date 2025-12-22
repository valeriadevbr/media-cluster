#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/.env"
set +a

"${K8S_PATH}/setup.sh"
"${K8S_PATH}/apply-all.sh"
if [[ "$(uname -s)" == "Darwin" ]]; then
  "${SETUP_PATH}/utils/set-pf-rules.sh"
fi
