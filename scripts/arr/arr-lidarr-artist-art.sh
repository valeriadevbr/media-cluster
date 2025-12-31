#!/bin/bash

# ==============================================================================
# Lidarr Connect Script - Artist Artwork Fetcher (Fanart.tv)
#
# Variáveis de Ambiente Fornecidas pelo Lidarr:
# - lidarr_eventtype: Tipo de evento (AlbumDownload, AlbumUpgrade)
# - lidarr_artist_name: Nome do artista
# - lidarr_artist_path: Caminho da pasta do artista
# - lidarr_artist_mbid: MusicBrainz Artist ID
#
# Variáveis de Ambiente Opcionais:
# - FANART_API_KEY: Chave de API do fanart.tv
#
# Dependências:
# - curl, jq, imagemagick (magick)
# ==============================================================================

exec 3>&1

# Constantes
readonly LOG_FILE="/tmp/arr-lidarr-artist-art.log"
readonly MIN_WIDTH=500
readonly COVER_SIZE="1200x1200"
readonly CURL_OPTS="--connect-timeout 10 --max-time 30 -s -L -A 'LidarrConnectScript/1.0'"
readonly CACHE_DIR="/tmp/arr-lidarr-coverart-cache"
readonly MAX_LOG_SIZE=$((1024 * 1024))
readonly CACHE_TTL_MINUTES=$((60 * 24 * 30)) # 30 dias
readonly FANART_API_KEY="${FANART_API_KEY:-}"

# Inicializa diretório de cache
if [[ ! -d "$CACHE_DIR" ]]; then
  mkdir -p "$CACHE_DIR"
fi

if [[ ! -f "$LOG_FILE" ]]; then
  touch "$LOG_FILE"
  chown "${PUID}:${PGID}" "$LOG_FILE" 2>/dev/null || true
  chmod 666 "$LOG_FILE"
fi

log_msg() {
  local msg="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] %s\n" "$timestamp" "$msg" | tee -a "$LOG_FILE" >&3
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

clean_cache() {
  if [[ -d "$CACHE_DIR" ]]; then
    local count=$(find "$CACHE_DIR" -type f -mmin +"$CACHE_TTL_MINUTES" | wc -l)
    if [[ "$count" -gt 0 ]]; then
      log_msg "Cache: Removendo $count arquivos expirados (> ${CACHE_TTL_MINUTES}min)."
      find "$CACHE_DIR" -type f -mmin +"$CACHE_TTL_MINUTES" -delete
    fi
  fi
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

is_cache_valid() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  if [[ $(find "$file" -mmin -"$CACHE_TTL_MINUTES" 2>/dev/null) ]]; then
    return 0
  fi
  return 1
}

check_dependencies() {
  for cmd in curl jq magick; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_msg "ERRO: Comando '$cmd' não encontrado."
      exit 1
    fi
  done
}

fetch_artist_json() {
  local artist_mbid="$lidarr_artist_mbid"
  local cache_file="${CACHE_DIR}/fanart-json-${artist_mbid}.json"

  if is_cache_valid "$cache_file"; then
    echo "$cache_file"
    return 0
  fi

  if [[ -z "$FANART_API_KEY" ]]; then
    log_msg "Aviso: FANART_API_KEY não configurada. Pulando fanart.tv."
    return 1
  fi

  local url="https://webservice.fanart.tv/v3/music/${artist_mbid}?api_key=${FANART_API_KEY}"
  log_msg "Buscando dados do artista no Fanart.tv: $artist_mbid"

  local tmp_json="${cache_file}.tmp"
  if curl $CURL_OPTS -f -o "$tmp_json" "$url" && [[ -s "$tmp_json" ]]; then
    mv "$tmp_json" "$cache_file"
    echo "$cache_file"
    return 0
  fi

  log_msg "Aviso: Falha ao obter dados do Fanart.tv para MBID: $artist_mbid"
  rm -f "$tmp_json"
  return 1
}

process_artist_image() {
  local target_file="$1" json_file="$2" image_type="$3" primary_field="$4" fallback_field="$5" needs_resize="$6"

  if [[ -f "$target_file" ]]; then
    log_msg "Arte do artista (${image_type}) já existe. Pulando."
    return 0
  fi

  if [[ ! -f "$json_file" ]]; then
    return 1
  fi

  # Extrai URL do JSON
  local img_url=$(jq -r ".${primary_field}[0].url // empty" "$json_file")
  if [[ -z "$img_url" && -n "$fallback_field" ]]; then
    img_url=$(jq -r ".${fallback_field}[0].url // empty" "$json_file")
  fi

  if [[ -z "$img_url" || "$img_url" == "null" ]]; then
    log_msg "Aviso: ${image_type} não encontrada no JSON do Fanart.tv."
    return 0
  fi

  local cache_key="fanart-img-$(get_md5 "$img_url")"
  local cache_file="${CACHE_DIR}/${cache_key}.$([[ "$image_type" == "Clear Logo" ]] && echo "png" || echo "jpg")"

  if ! is_cache_valid "$cache_file"; then
    log_msg "Baixando ${image_type}: $img_url"
    local tmp_img="${cache_file}.tmp"
    if ! curl $CURL_OPTS -o "$tmp_img" "$img_url" || [[ ! -s "$tmp_img" ]]; then
      log_msg "Erro: Falha no download de ${image_type}."
      rm -f "$tmp_img"
      return 1
    fi

    if [[ "$needs_resize" == "true" ]]; then
      local width=$(magick identify -format "%w" "$tmp_img" 2>/dev/null)
      if [[ -z "$width" || "$width" -lt "$MIN_WIDTH" ]]; then
        log_msg "Erro: Imagem muito pequena (${width}px)."
        rm -f "$tmp_img"
        return 1
      fi
      log_msg "Redimensionando ${image_type} para ${COVER_SIZE}..."
      magick "$tmp_img" -resize "${COVER_SIZE}>" -quality 95 "$cache_file"
    else
      if ! magick identify "$tmp_img" >/dev/null 2>&1; then
        log_msg "Erro: Imagem inválida."
        rm -f "$tmp_img"
        return 1
      fi
      cp "$tmp_img" "$cache_file"
    fi
    rm -f "$tmp_img"
  fi

  log_msg "Salvando arte do artista (${image_type})."
  cp "$cache_file" "$target_file"
  return 0
}

# Principal
check_dependencies
rotate_log_if_needed
clean_cache

if [[ "$lidarr_eventtype" == "Test" ]]; then
  log_msg ""
  log_msg "======================================================================"
  log_msg "Evento: $lidarr_eventtype"
  log_msg "Teste de conexão: OK."
  log_msg "======================================================================"
  log_msg ""
  exit 0
fi

if [[ ! "$lidarr_eventtype" =~ ^(AlbumDownload|AlbumUpgrade|TrackRetag)$ ]]; then
  log_msg ""
  log_msg "======================================================================"
  log_msg "Evento: $lidarr_eventtype"
  log_msg "Evento não suportado: ignorando."
  log_msg "======================================================================"
  log_msg ""
  exit 0
fi

ARTIST_DIR="$lidarr_artist_path"
if [[ -z "$ARTIST_DIR" || ! -d "$ARTIST_DIR" ]]; then
  log_msg "Erro: Pasta do artista não encontrada: $ARTIST_DIR"
  exit 1
fi

log_msg ""
log_msg "======================================================================"
log_msg "Evento: $lidarr_eventtype"
log_msg "Processando artista: $lidarr_artist_name"
log_msg "======================================================================"
log_msg ""

JSON_FILE=$(fetch_artist_json)

process_artist_image "${ARTIST_DIR}/artist.jpg" "$JSON_FILE" "Artist Art" "artistthumb" "" "true"

# Garantir folder.jpg como hardlink de artist.jpg
if [[ -f "${ARTIST_DIR}/artist.jpg" ]]; then
  if [[ ! -f "${ARTIST_DIR}/folder.jpg" ]]; then
    log_msg "Criando hardlink: folder.jpg -> artist.jpg"
    ln "${ARTIST_DIR}/artist.jpg" "${ARTIST_DIR}/folder.jpg"
  elif [[ ! "${ARTIST_DIR}/artist.jpg" -ef "${ARTIST_DIR}/folder.jpg" ]]; then
    # Se existirem mas não forem o mesmo arquivo (hardlink), forçar o link
    log_msg "Sincronizando folder.jpg (hardlink) com artist.jpg"
    ln -f "${ARTIST_DIR}/artist.jpg" "${ARTIST_DIR}/folder.jpg"
  fi
fi
process_artist_image "${ARTIST_DIR}/clearlogo.png" "$JSON_FILE" "Clear Logo" "hdmusiclogo" "musiclogo" "false"
process_artist_image "${ARTIST_DIR}/fanart.jpg" "$JSON_FILE" "Background" "artistbackground" "" "true"

exit 0
