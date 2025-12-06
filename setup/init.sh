#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/includes/setup_vars.sh"

# Build das imagens customizadas Sonarr e Radarr com mkvtoolnix CLI
echo "Construindo imagem $SONARR_IMAGE..."
if docker build -t "$SONARR_IMAGE" -f "$SONARR_DOCKERFILE" "$DOCKER_CONTEXT"; then
  echo "Imagem $SONARR_IMAGE criada com sucesso!"
else
  echo "Erro ao criar a imagem $SONARR_IMAGE" >&2
  exit 1
fi

echo "Construindo imagem $RADARR_IMAGE..."
if docker build -t "$RADARR_IMAGE" -f "$RADARR_DOCKERFILE" "$DOCKER_CONTEXT"; then
  echo "Imagem $RADARR_IMAGE criada com sucesso!"
else
  echo "Erro ao criar a imagem $RADARR_IMAGE" >&2
  exit 1
fi

# Sobe os containers usando o docker-compose.yml na raiz do projeto
docker compose -f "$DOCKER_COMPOSE_FILE" up -d
