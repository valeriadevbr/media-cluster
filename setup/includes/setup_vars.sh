#!/bin/bash

# Variáveis compartilhadas para scripts de setup
SETUP_DIR="/Volumes/Plex/setup"

CONFIGS_DIR="$SETUP_DIR/../configs"
DOCKER_COMPOSE_FILE="$SETUP_DIR/docker-compose.yml"
DOCKER_CONTEXT="$SETUP_DIR/docker-image"
RADARR_DOCKERFILE="$SETUP_DIR/docker-image/radarr.dockerfile"
RADARR_IMAGE="radarr-mkvtoolnix"
SONARR_DOCKERFILE="$SETUP_DIR/docker-image/sonarr.dockerfile"
SONARR_IMAGE="sonarr-mkvtoolnix"
SSL_CONFIG_DIR="$CONFIGS_DIR/ssl"
WAN_HOST="apedamo.duckdns.org"
