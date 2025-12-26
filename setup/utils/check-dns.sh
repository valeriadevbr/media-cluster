#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/load-env.sh"
set +a

echo "Verificando compatibilidade com Caddy..."

# Hosts definidos no Caddy
hosts=(
  "bazarr"
  "dashboard"
  "emby"
  "jackett"
  "lidarr"
  "plex"
  "profilarr"
  "prowlarr"
  "qbittorrent"
  "radarr"
  "slskd"
  "sonarr"
)

zone_file="${CONFIGS_PATH}/bind/config/zones/db.media.lan"

echo "Hosts no Caddy: ${#hosts[@]}"
echo "Hosts no arquivo de zona:"

for host in "${hosts[@]}"; do
  if grep -q "^${host}[[:space:]]" "${zone_file}"; then
    echo "  ✓ $host.media.lan"
  else
    echo "  ✗ $host.media.lan (FALTANDO!)"
  fi
done

# Verificar wildcard
if grep -q "^\*\.media\.lan\." "${zone_file}"; then
  echo "✓ Wildcard *.media.lan configurado"
else
  echo "✗ Wildcard não encontrado"
fi
