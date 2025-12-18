#!/bin/bash
set -e
set -a
source "$(dirname -- "$0")/.env"
set +a

# Para os containers usando o docker-compose.yml na raiz do projeto
docker compose -f "$COMPOSE_FILE_PATH" down
