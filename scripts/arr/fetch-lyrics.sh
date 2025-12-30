#!/bin/bash

# ==============================================================================
# Lidarr Batch Lyrics Scanner (fetch-lyrics.sh)
#
# Este script consulta a API do Lidarr para obter todas as faixas e executa
# o script arr-lidarr-lyrics.sh para cada uma que possua um arquivo físico.
#
# Configuração:
# As variáveis LIDARR_URL e LIDARR_API_KEY devem estar definidas no ambiente
# ou em um arquivo .env na mesma pasta (suporta auto-detecção via config.xml).
# ==============================================================================

LIDARR_CONFIG="/config/config.xml"
LYRICS_SCRIPT="$(dirname "$0")/arr-lidarr-lyrics.sh"
ARTIST_FILTER="$1"

if [ -z "$lidarrUrl" ] || [ -z "$lidarrApiKey" ]; then
  if [[ ! -f "$LIDARR_CONFIG" ]]; then
    log_msg "ERRO: Arquivo de configuração não encontrado em $LIDARR_CONFIG"
    exit 1
  fi

  lidarrUrlBase="$(cat "$LIDARR_CONFIG" | xq | jq -r '.Config.UrlBase // empty')"
  if [[ -z "$lidarrUrlBase" || "$lidarrUrlBase" == "null" ]]; then
    lidarrUrlBase=""
  else
    lidarrUrlBase="/$(echo "$lidarrUrlBase" | sed "s/\///g")"
  fi
  lidarrApiKey="$(cat "$LIDARR_CONFIG" | xq | jq -r .Config.ApiKey)"
  lidarrPort="$(cat "$LIDARR_CONFIG" | xq | jq -r .Config.Port)"
  lidarrUrl="http://127.0.0.1:${lidarrPort}${lidarrUrlBase}"
fi

if [ -z "$lidarr_album_id" ]; then
  lidarr_album_id="$1"
fi

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

handle_interrupt() {
  echo ""
  log_msg "Execução interrompida pelo usuário (SIGINT/SIGTERM)."
  exit 130
}

trap handle_interrupt SIGINT SIGTERM

if [[ -z "$lidarrApiKey" ]]; then
  log_msg "ERRO: lidarrApiKey não definida em $LIDARR_CONFIG."
  exit 1
fi

if [[ ! -f "$LYRICS_SCRIPT" ]]; then
  log_msg "ERRO: Script de letras não encontrado em: $LYRICS_SCRIPT"
  exit 1
fi

log_msg "Iniciando varredura no Lidarr: $lidarrUrl"
if [[ -n "$ARTIST_FILTER" ]]; then
  log_msg "Filtro de artista: $ARTIST_FILTER"
fi

log_msg "Buscando lista de artistas..."

res_artists=$(curl -s -L -w "\n%{http_code}" -H "X-Api-Key: $lidarrApiKey" \
  "${lidarrUrl}/api/v1/artist")
status_artists=$(echo "$res_artists" | tail -n1)
artists_json=$(echo "$res_artists" | sed '$d')

if [[ "$status_artists" != "200" ]]; then
  log_msg "ERRO: Falha ao buscar artistas (Status HTTP: $status_artists)."
  exit 1
fi

# Filtra artistas se houver filtro (comparação robusta alfanumérica)
if [[ -n "$ARTIST_FILTER" ]]; then
  # Remove tudo que não é letra/número para comparação
  artists_to_process=$(echo "$artists_json" | jq -c --arg f "$ARTIST_FILTER" '
    .[] | select(
      (.artistName | ascii_downcase | gsub("[^a-z0-9]"; ""))
      | contains ($f | ascii_downcase | gsub("[^a-z0-9]"; ""))
    )')
else
  artists_to_process=$(echo "$artists_json" | jq -c '.[]')
fi

if [[ -z "$artists_to_process" ]]; then
  log_msg "Nenhum artista encontrado com o filtro: $ARTIST_FILTER"
  exit 0
fi

artist_count=$(echo "$artists_to_process" | grep -c .)
log_msg "Encontrados $artist_count artistas para processar."

count_artist=0
echo "$artists_to_process" | while read -r artist; do
  if [[ -z "$artist" ]]; then
    continue
  fi

  ((count_artist++))

  artist_id=$(echo "$artist" | jq -r '.id')
  artist_name=$(echo "$artist" | jq -r '.artistName')

  if [[ -z "$artist_id" || "$artist_id" == "null" ]]; then
    continue
  fi

  msg="[$count_artist/$artist_count] Buscando faixas de: $artist_name"
  log_msg "$msg (ID: $artist_id)"

  # Busca faixas, arquivos e álbuns do artista (v1 não inclui tudo no /track)
  res_tracks=$(curl $CURL_OPTS -H "X-Api-Key: $lidarrApiKey" \
    "${lidarrUrl}/api/v1/track?artistId=${artist_id}")
  res_files=$(curl $CURL_OPTS -H "X-Api-Key: $lidarrApiKey" \
    "${lidarrUrl}/api/v1/trackfile?artistId=${artist_id}")
  res_albums=$(curl $CURL_OPTS -H "X-Api-Key: $lidarrApiKey" \
    "${lidarrUrl}/api/v1/album?artistId=${artist_id}")

  # Check if curl commands were successful
  if [ $? -ne 0 ]; then
    log_msg "  Aviso: Falha ao buscar dados para $artist_name. Pulando."
    continue
  fi

  # Junta faixas, arquivos e álbuns usando jq
  tracks_json=$(echo "$res_tracks $res_files $res_albums" | jq -s '
    .[0] as $tracks | .[1] as $files | .[2] as $albums |
    $tracks | map(. as $t |
    if $t.trackFileId > 0 then
      . + {trackFile: ($files | .[] | select(.id == $t.trackFileId))}
    else . end
    | . + {album: ($albums | .[] | select(.id == $t.albumId))})')

  # Filtra faixas que possuem arquivo físico
  tracks_with_file=$(echo "$tracks_json" |
    jq -c '.[] | select(.hasFile == true and .trackFile.path != null)')
  track_count=$(echo "$tracks_with_file" | jq -s 'length')

  if [[ "$track_count" -eq 0 ]]; then
    log_msg "  Nenhuma faixa com arquivo encontrada para este artista."
    continue
  fi

  log_msg "  Processando $track_count faixas..."

  while read -r track; do
    if [[ -z "$track" ]]; then
      continue
    fi

    export lidarr_eventtype="TrackRetag"
    export lidarr_artist_name="$artist_name"
    export lidarr_album_title=$(echo "$track" |
      jq -r '.album.title // .albumTitle // "Unknown Album"')
    export lidarr_trackfile_path=$(echo "$track" | jq -r '.trackFile.path')
    export lidarr_trackfile_tracktitles=$(echo "$track" | jq -r '.title')

    bash "$LYRICS_SCRIPT"

    sleep 0.1
  done <<<"$tracks_with_file"
done

log_msg "Varredura concluída."
