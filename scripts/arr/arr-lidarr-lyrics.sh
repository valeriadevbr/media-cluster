#!/bin/bash

# ==============================================================================
# Lidarr Connect Script - Lyrics Fetcher & Embedder
#
# Variáveis de Ambiente Fornecidas pelo Lidarr (TrackRetag):
# - lidarr_eventtype: TrackRetag/AlbumDownload/etc
# - lidarr_artist_name: Nome do artista
# - lidarr_album_title: Título do álbum
# - lidarr_trackfile_path: Caminho do arquivo
# - lidarr_trackfile_tracktitles: Títulos das faixas (separados por '|')
#
# Dependências:
# - curl, jq, kid3-cli, ffprobe
# ==============================================================================

readonly LOG_FILE="/tmp/arr-lidarr-lyrics.log"
readonly CACHE_DIR="/tmp/arr-lidarr-lyrics-cache"
readonly MAX_LOG_SIZE=$((1024 * 1024))
readonly CURL_OPTS="--connect-timeout 5 --max-time 15 -s -L -A 'LidarrLyricsScript/1.0'"
readonly GENIUS_API_KEY="${GENIUS_API_KEY:-}"

if [[ ! -d "$CACHE_DIR" ]]; then
  mkdir -p "$CACHE_DIR"
fi

log_msg() {
  local msg="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] %s\n" "$timestamp" "$msg" | tee -a "$LOG_FILE" >&2
}

rotate_log_if_needed() {
  if [[ ! -f "$LOG_FILE" ]]; then
    return 0
  fi

  local log_size
  if [[ "$(uname)" == "Linux" ]]; then
    log_size=$(stat -c %s "$LOG_FILE" 2>/dev/null)
  else
    log_size=$(stat -f %z "$LOG_FILE" 2>/dev/null)
  fi

  if [[ -n "$log_size" && "$log_size" -ge "$MAX_LOG_SIZE" ]]; then
    >"$LOG_FILE"
  fi
}

check_dependencies() {
  for cmd in curl jq kid3-cli ffprobe; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_msg "ERRO: Comando '$cmd' não encontrado."
      exit 1
    fi
  done
}

get_md5() {
  if command -v md5sum >/dev/null 2>&1; then
    echo -n "$1" | md5sum | awk '{print $1}'
  elif command -v md5 >/dev/null 2>&1; then
    echo -n "$1" | md5 -q
  else
    echo -n "$1" | cksum | awk '{print $1}'
  fi
}

get_track_duration() {
  local file="${1}"
  ffprobe \
    -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "${file}" | awk '{print int($1)}' 2>/dev/null
}

check_existing_lyrics() {
  local file="$1"
  local lyrics=$(kid3-cli -c "get lyrics" "$file" 2>/dev/null | grep -v "Failed to create")
  if [[ -n "$lyrics" && "$lyrics" != "null" ]]; then
    return 0
  fi
  return 1
}

fetch_lrclib() {
  local artist="$1" album="$2" title="$3" duration="$4"
  local cache_key=$(get_md5 "lrclib-${artist}-${title}-${duration}")
  local cache_file="${CACHE_DIR}/${cache_key}.txt"

  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
    return 0
  fi

  local res=$(curl $CURL_OPTS -G \
    --data-urlencode "artist_name=$artist" \
    --data-urlencode "track_name=$title" \
    --data-urlencode "album_name=$album" \
    --data-urlencode "duration=$duration" \
    "https://lrclib.net/api/get")

  local lyrics=$(echo "$res" | jq -r ".syncedLyrics // .plainLyrics // empty")

  if [[ -z "$lyrics" || "$lyrics" == "null" ]]; then
    res=$(curl $CURL_OPTS -G \
      --data-urlencode "artist_name=$artist" \
      --data-urlencode "track_name=$title" \
      "https://lrclib.net/api/search")
    lyrics=$(echo "$res" | jq -r ".[0].syncedLyrics // .[0].plainLyrics // empty")
  fi

  if [[ -n "$lyrics" ]]; then
    echo "$lyrics" >"$cache_file"
    echo "$lyrics"
    return 0
  fi

  return 1
}

fetch_lyrics_ovh() {
  local artist="$1" title="$2"
  local cache_key=$(get_md5 "ovh-${artist}-${title}")
  local cache_file="${CACHE_DIR}/${cache_key}.txt"

  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
    return 0
  fi

  local res=$(curl $CURL_OPTS "https://api.lyrics.ovh/v1/${artist}/${title}")
  local lyrics=$(echo "$res" | jq -r ".lyrics // empty")

  if [[ -n "$lyrics" ]]; then
    echo "$lyrics" >"$cache_file"
    echo "$lyrics"
    return 0
  fi
  return 1
}
fetch_genius() {
  local artist="$1" title="$2"

  if [[ -z "$GENIUS_API_KEY" ]]; then
    return 1
  fi

  local res=$(curl $CURL_OPTS -H "Authorization: Bearer $GENIUS_API_KEY" \
    -G --data-urlencode "q=$artist $title" \
    "https://api.genius.com/search")

  # Get the first hit
  local hit=$(echo "$res" | jq -c ".response.hits[0].result")
  local song_url=$(echo "$hit" | jq -r ".url // empty")

  if [[ -z "$song_url" ]]; then
    return 1
  fi

  # Validate artist match
  local valid_artist=$(echo "$hit" | jq --arg a "$artist" -r '
    (.primary_artist.name | ascii_downcase | gsub("[^a-z0-9]"; "")) as $genius_artist |
    ($a | ascii_downcase | gsub("[^a-z0-9]"; "")) as $req_artist |
    if ($genius_artist | contains($req_artist)) or ($req_artist | contains($genius_artist)) then "valid" else empty end
  ')

  if [[ -z "$valid_artist" ]]; then
    log_msg "Genius: Artista incompatível ($(echo "$hit" | jq -r .primary_artist.name)). Pulando." >&2
    return 1
  fi

  # Fetch HTML and parse with Python
  local lyrics=$(curl $CURL_OPTS "$song_url" | python3 /opt/scripts/resources/genius_scraper.py)

  if [[ -n "$lyrics" ]]; then
    echo "$lyrics"
    return 0
  fi
  return 1
}

embed_lyrics() {
  local file="$1"
  local lyrics="$2"

  local orig_mod=$(stat -c %y "$file")
  local escaped_lyrics="${lyrics//\'/\'\\\'\'}"
  local msg=$(kid3-cli -c "set lyrics '$escaped_lyrics'" "$file" 2>&1)

  if [[ $? -eq 0 ]]; then
    touch -d "$orig_mod" "$file"
    log_msg "Sucesso: Letras embutidas em ${file##*/}"
    return 0
  else
    log_msg "Erro ao embutir em ${file##*/}: $msg"
    return 1
  fi
}

# Principal
check_dependencies
rotate_log_if_needed

if [[ "$lidarr_eventtype" == "Test" ]]; then
  log_msg ""
  log_msg "======================================================================"
  log_msg "Evento: $lidarr_eventtype"
  log_msg "Teste de conexão: OK."
  log_msg "======================================================================"
  log_msg ""
  exit 0
fi

if [[ ! "$lidarr_eventtype" =~ ^(TrackRetag)$ ]]; then
  log_msg ""
  log_msg "======================================================================"
  log_msg "Evento: $lidarr_eventtype"
  log_msg "Evento não suportado: ignorando."
  log_msg "======================================================================"
  log_msg ""
  exit 0
fi

FILE_PATH="$lidarr_trackfile_path"

if [[ -z "$FILE_PATH" ]]; then
  log_msg "Erro: Caminho do arquivo (lidarr_trackfile_path) não fornecido."
  exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
  log_msg "Erro: Arquivo não encontrado: $FILE_PATH"
  exit 0
fi

ARTIST="$lidarr_artist_name"
ALBUM="$lidarr_album_title"
TITLE="${lidarr_trackfile_tracktitles%%|*}"

log_msg ""
log_msg "======================================================================"
log_msg "Evento: $lidarr_eventtype"
log_msg "Processando: $ARTIST - $ALBUM - $TITLE"
log_msg "======================================================================"
log_msg ""

if [[ "${FORCE_LYRICS:-false}" == "true" ]]; then
  log_msg "Modo FORCE: Sobrescrevendo letras existentes."
elif check_existing_lyrics "$FILE_PATH"; then
  log_msg "Aviso: Letras já presentes. Pulando."
  exit 0
fi

DURATION=$(get_track_duration "$FILE_PATH")
LRC_FILE="${FILE_PATH%.*}.lrc"
LOCAL_LRC=false
LYRICS=""

if [[ -f "$LRC_FILE" ]]; then
  log_msg "Fonte: Arquivo local (.lrc) encontrado."
  LYRICS=$(cat "$LRC_FILE")
  LOCAL_LRC=true
else
  log_msg "Buscando letras nas APIs (Duração: ${DURATION}s)..."
  if LYRICS=$(fetch_lrclib "$ARTIST" "$ALBUM" "$TITLE" "$DURATION") && [[ -n "$LYRICS" ]]; then
    log_msg "Fonte: LRCLIB"
  elif LYRICS=$(fetch_lyrics_ovh "$ARTIST" "$TITLE") && [[ -n "$LYRICS" ]]; then
    log_msg "Fonte: Lyrics.ovh"
  elif [[ "${USE_GENIUS_FALLBACK:-false}" == "true" ]] &&
    LYRICS=$(fetch_genius "$ARTIST" "$TITLE") &&
    [[ -n "$LYRICS" ]]; then
    log_msg "Fonte: Genius"
  fi
fi

if [[ -z "$LYRICS" ]]; then
  log_msg "Aviso: Nenhuma letra encontrada para $ARTIST - $TITLE"
  exit 0
fi

if embed_lyrics "$FILE_PATH" "$LYRICS"; then
  if [[ "$LOCAL_LRC" == "true" ]]; then
    log_msg "Limpando arquivo .lrc após embutimento bem-sucedido."
    rm -f "$LRC_FILE"
  fi
fi

exit 0
