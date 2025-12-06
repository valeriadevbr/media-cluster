#!/bin/bash
set -e

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/.env"

# Build das imagens customizadas Sonarr e Radarr com mkvtoolnix CLI
echo "Construindo imagem $SONARR_IMAGE_NAME..."
if docker build -t "$SONARR_IMAGE_NAME" -f "$SONARR_DOCKERFILE_PATH" "$DOCKER_BUILD_CONTEXT"; then
  echo "Imagem $SONARR_IMAGE_NAME criada com sucesso!"
else
  echo "Erro ao criar a imagem $SONARR_IMAGE_NAME" >&2
  exit 1
fi

echo "Construindo imagem $RADARR_IMAGE_NAME..."
if docker build -t "$RADARR_IMAGE_NAME" -f "$RADARR_DOCKERFILE_PATH" "$DOCKER_BUILD_CONTEXT"; then
  echo "Imagem $RADARR_IMAGE_NAME criada com sucesso!"
else
  echo "Erro ao criar a imagem $RADARR_IMAGE_NAME" >&2
  exit 1
fi

# Sobe os containers usando o docker-compose.yml na raiz do projeto
docker compose -f "$COMPOSE_FILE_PATH" up -d
