#!/usr/bin/env bash
set -e
set -a
source "$(dirname -- "$0")/../.env"
. "${SETUP_PATH}/includes/k8s-utils.sh"
PUID=$(id -u)
PGID=$(id -g)
set +a
