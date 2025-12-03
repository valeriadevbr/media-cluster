#!/bin/bash

# Build da imagem customizada do Sonarr com mkvtoolnix CLI
DOCKERFILE_PATH="$(dirname "$0")/../docker-image/sonarr.dockerfile"
DOCKER_COMPOSE_FILE="$(dirname "$0")/../docker-compose.yml"
IMAGE_NAME="sonarr-mkvtoolnix"
BUILD_CONTEXT="$(dirname "$DOCKERFILE_PATH")"

# Faz o build da imagem
if docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" "$BUILD_CONTEXT"; then
  echo "Imagem $IMAGE_NAME criada com sucesso!"
else
  echo "Erro ao criar a imagem $IMAGE_NAME" >&2
  exit 1
fi

# Sobe os containers usando o docker-compose.yml na raiz do projeto
docker compose -f "$DOCKER_COMPOSE_FILE" up -d
