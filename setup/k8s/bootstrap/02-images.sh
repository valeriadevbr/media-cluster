#!/bin/bash
set -e

echo "Building Sonarr custom image..."
docker build -t "$SONARR_IMAGE_NAME" -f "$SONARR_DOCKERFILE_PATH" "$DOCKER_BUILD_CONTEXT" >/dev/null
echo "Loading Sonarr image into Kind..."
kind load docker-image "$SONARR_IMAGE_NAME" --name "$CLUSTER_NAME" >/dev/null

echo "Building Radarr custom image..."
docker build -t "$RADARR_IMAGE_NAME" -f "$RADARR_DOCKERFILE_PATH" "$DOCKER_BUILD_CONTEXT" >/dev/null
echo "Loading Radarr image into Kind..."
kind load docker-image "$RADARR_IMAGE_NAME" --name "$CLUSTER_NAME" >/dev/null
