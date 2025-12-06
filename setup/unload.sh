#!/bin/bash

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/.env"

# Para os containers usando o docker-compose.yml na raiz do projeto
docker compose -f "$COMPOSE_FILE_PATH" down
