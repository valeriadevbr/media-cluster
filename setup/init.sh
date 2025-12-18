#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/.env"
set +a

docker compose -f "$COMPOSE_FILE_PATH" up -d
