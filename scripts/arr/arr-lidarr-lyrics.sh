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
FORCE_LYRICS="${FORCE_LYRICS:-false}"

log_msg() {
  local msg="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] %s\n" "$timestamp" "$msg" | tee -a "$LOG_FILE" >&2
}

check_dependencies() {
  for cmd in curl jq kid3-cli; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_msg "ERRO: Comando '$cmd' não encontrado."
      exit 1
    fi
  done
}

check_existing_lyrics() {
  local file="$1"
  local lyrics=$(kid3-cli -c "get lyrics" "$file" 2>/dev/null | grep -v "Failed to create")

  if [[ -z "$lyrics" || "$lyrics" == "null" ]]; then
    return 1
  fi

  if echo "$lyrics" | grep -qE "\[[0-9]{2}:[0-9]{2}(\.[0-9]{2,3})?\]"; then
    return 0
  fi

  return 1
}

fetch_synced_lyrics() {
  local artist="$1" title="$2"

  local lyrics=$(python3 /opt/scripts/resources/synced_lyrics_fetcher.py \
    "$artist" "$title")

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

check_dependencies

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

if [[ "$FORCE_LYRICS" == "true" ]]; then
  log_msg "Modo FORCE: Sobrescrevendo letras existentes."
elif check_existing_lyrics "$FILE_PATH"; then
  log_msg "Aviso: Letras sincronizadas já presentes. Pulando."
  exit 0
fi

LRC_FILE="${FILE_PATH%.*}.lrc"
LOCAL_LRC=false
LYRICS=""

if [[ -f "$LRC_FILE" ]]; then
  log_msg "Fonte: Arquivo local (.lrc) encontrado."
  LYRICS=$(cat "$LRC_FILE")
  LOCAL_LRC=true
else
  log_msg "Buscando letras via syncedlyrics..."
  if LYRICS=$(fetch_synced_lyrics "$ARTIST" "$TITLE") && [[ -n "$LYRICS" ]]; then
    log_msg "Fonte: syncedlyrics"
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
