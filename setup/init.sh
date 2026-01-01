#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/includes/load-env.sh"
set +a

"${K8S_PATH}/setup.sh"
"${K8S_PATH}/apply-all.sh"

if [[ "$OS" == "Darwin" ]]; then
  "${SETUP_PATH}/utils/set-pf-rules.sh"
  sudo sysctl -w kern.maxfiles=1048576
  sudo sysctl -w kern.maxfilesperproc=1048576
fi
