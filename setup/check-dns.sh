#!/bin/bash
# verify-migration.sh
echo "Verificando compatibilidade com Caddy..."

# Carrega variáveis compartilhadas
source "$(dirname -- "$0")/.env"

# Hosts definidos no Caddy
caddy_hosts=("plex" "emby" "bazarr" "jackett" "lidarr" "profilarr"
  "prowlarr" "radarr" "sonarr" "qbittorrent" "slskd")

zone_file="${CONFIGS_PATH}/bind/config/zones/db.media.lan"

echo "Hosts no Caddy: ${#caddy_hosts[@]}"
echo "Hosts no arquivo de zona:"

for host in "${caddy_hosts[@]}"; do
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
