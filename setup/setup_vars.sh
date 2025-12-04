#!/bin/bash

# Variáveis compartilhadas para scripts de setup
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
DOCKER_CONTEXT="$SCRIPT_DIR/docker-image"
RADARR_DOCKERFILE="$SCRIPT_DIR/docker-image/radarr.dockerfile"
RADARR_IMAGE="radarr-mkvtoolnix"
SONARR_DOCKERFILE="$SCRIPT_DIR/docker-image/sonarr.dockerfile"
SONARR_IMAGE="sonarr-mkvtoolnix"
