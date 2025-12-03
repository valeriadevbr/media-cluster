#!/bin/bash

# Build das imagens customizadas Sonarr e Radarr com mkvtoolnix CLI
SONARR_DOCKERFILE="$(dirname "$0")/../docker-image/sonarr.dockerfile"
RADARR_DOCKERFILE="$(dirname "$0")/../docker-image/radarr.dockerfile"
DOCKER_COMPOSE_FILE="$(dirname "$0")/../docker-compose.yml"
SONARR_IMAGE="sonarr-mkvtoolnix"
RADARR_IMAGE="radarr-mkvtoolnix"
SONARR_CONTEXT="$(dirname "$SONARR_DOCKERFILE")"
RADARR_CONTEXT="$(dirname "$RADARR_DOCKERFILE")"

echo "Construindo imagem $SONARR_IMAGE..."
if docker build -t "$SONARR_IMAGE" -f "$SONARR_DOCKERFILE" "$SONARR_CONTEXT"; then
  echo "Imagem $SONARR_IMAGE criada com sucesso!"
else
  echo "Erro ao criar a imagem $SONARR_IMAGE" >&2
  exit 1
fi

echo "Construindo imagem $RADARR_IMAGE..."
if docker build -t "$RADARR_IMAGE" -f "$RADARR_DOCKERFILE" "$RADARR_CONTEXT"; then
  echo "Imagem $RADARR_IMAGE criada com sucesso!"
else
  echo "Erro ao criar a imagem $RADARR_IMAGE" >&2
  exit 1
fi

# Sobe os containers usando o docker-compose.yml na raiz do projeto
docker compose -f "$DOCKER_COMPOSE_FILE" up -d
