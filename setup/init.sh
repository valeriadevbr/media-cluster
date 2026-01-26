#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/includes/load-env.sh"
set +a

"${K8S_PATH}/setup.sh"

if [[ "$OS" == "Darwin" ]]; then
  sudo sysctl -w kern.maxfiles=1048576
  sudo sysctl -w kern.maxfilesperproc=1048576
  "${SETUP_PATH}/utils/set-pf-rules.sh"
fi
