#!/bin/bash

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/setup_vars.sh"

# Para os containers usando o docker-compose.yml na raiz do projeto
docker compose -f "$DOCKER_COMPOSE_FILE" down
