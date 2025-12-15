#!/bin/bash
set -e

source "$(dirname -- "$0")/.env"
docker compose -f "$COMPOSE_FILE_PATH" up -d
