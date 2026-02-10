#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
set +a

# Call the core backup script
"$(dirname -- "$0")/../../scripts/k8s/backup-wan-cert.sh" "$@"
