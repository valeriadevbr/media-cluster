#!/bin/bash

# Script to enable or disable additional media apps by scaling them in Kubernetes.
# Usage: ./enable-additional-media-apps.sh [1|0]
# Default: 1 (enable/scale to 1)

NAMESPACE="media"
TARGET_REPLICAS=${1:-1}

# Function to display help
show_help() {
  echo "Usage: $0 [1|0]"
  echo "  1: Enable (scale to 1) - Default"
  echo "  0: Disable (scale to 0)"
  echo "  Other values will display this help message."
}

# Validate argument
if [[ -n "$1" ]]; then
  if [[ "$1" != "0" && "$1" != "1" ]]; then
    show_help
    exit 1
  fi
fi

echo "Scaling applications to ${TARGET_REPLICAS} replicas in namespace '${NAMESPACE}'..."

apps=(
  "statefulset/radarr"
  "statefulset/sonarr"
  "statefulset/lidarr"
  "statefulset/lingarr"
  "statefulset/bazarr"
  "statefulset/prowlarr"
  "deployment/jackett"
  "statefulset/profilarr"
  "deployment/flaresolverr"
  "deployment/webshare"
  "statefulset/qbittorrent"
  "statefulset/slskd"
)

for app_entry in "${apps[@]}"; do
  IFS="/" read -r type name <<<"$app_entry"
  echo "Scaling $type/$name to $TARGET_REPLICAS..."
  kubectl scale "$type" "$name" --replicas="$TARGET_REPLICAS" -n "$NAMESPACE"
done

echo "Done."
