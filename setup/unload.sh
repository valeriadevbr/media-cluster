#!/bin/bash
set -ea
source "$(dirname -- "$0")/.env"
set +a

# Para os containers usando o docker-compose.yml na raiz do projeto
docker compose -f "$COMPOSE_FILE_PATH" down
