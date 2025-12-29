#!/bin/bash

# ==============================================================================
# Lidarr Connect Script - Cover Art Fetcher & Embedder
#
# Variáveis de Ambiente Fornecidas pelo Lidarr:
# - lidarr_eventtype: Tipo de evento (AlbumDownload, TrackRetag, AlbumUpgrade, Test)
# - lidarr_artist_name: Nome do artista
# - lidarr_artist_path: Caminho da pasta do artista
# - lidarr_artist_mbid: MusicBrainz Artist ID
# - lidarr_album_title: Título do álbum
# - lidarr_album_path: Caminho da pasta do álbum
# - lidarr_addedtrackpaths: Lista de arquivos processados (separados por pipe '|')
# - lidarr_album_mbid: MusicBrainz Release Group ID (ou Release ID dependendo da versão)
# - lidarr_albumrelease_mbid: MusicBrainz Release ID
#
# - curl: Para baixar a arte do iTunes/MusicBrainz
# - kid3-cli: Para embutir a arte nos arquivos de áudio
# - sed: Para processamento de strings (JSON parsing simples)
# - imagemagick: Para validação e redimensionamento de imagens
# ==============================================================================

# Constantes
readonly LOG_FILE="/tmp/arr-lidarr-album-art.log"
readonly MIN_WIDTH=500
readonly COVER_SIZE="1200x1200"
readonly CURL_OPTS="--connect-timeout 10 --max-time 30 -s -L \
-A 'LidarrConnectScript/1.0'"
readonly CACHE_DIR="/tmp/arr-lidarr-coverart-cache"
readonly MAX_LOG_SIZE=$((1024 * 1024))       # 1MB
readonly CACHE_TTL_MINUTES=$((60 * 24 * 30)) # 30 dias

# Inicializa diretório de cache
if [[ ! -d "$CACHE_DIR" ]]; then
  mkdir -p "$CACHE_DIR"
fi

log_msg() {
  local msg="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] %s\n" "$timestamp" "$msg" | tee -a "$LOG_FILE"
}

rotate_log_if_needed() {
  if [[ -f "$LOG_FILE" ]]; then
    local log_size
    if [[ "$(uname)" == "Linux" ]]; then
      log_size=$(stat -c %s "$LOG_FILE" 2>/dev/null)
    else
      log_size=$(stat -f %z "$LOG_FILE" 2>/dev/null)
    fi

    if [[ -n "$log_size" && "$log_size" -ge "$MAX_LOG_SIZE" ]]; then
      >"$LOG_FILE"
    fi
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

get_cache_path() {
  local key="$1"
  local hash=$(get_md5 "$key")
  echo "${CACHE_DIR}/${hash}.jpg"
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
  local missing=0
  for cmd in curl sed kid3-cli magick; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_msg "ERRO: Comando '$cmd' não encontrado."
      missing=1
    fi
  done

  if [[ $missing -eq 1 ]]; then
    exit 1
  fi
}

get_target_dir() {
  if [[ -n "$lidarr_addedtrackpaths" ]]; then
    local first_track="${lidarr_addedtrackpaths%%|*}"
    echo "${first_track%/*}"
  elif [[ -n "$lidarr_trackfile_path" ]]; then
    dirname "$lidarr_trackfile_path"
  else
    echo "$lidarr_album_path"
  fi
}

fetch_itunes_cover() {
  local output_file="$1"
  local search_term="${lidarr_artist_name} ${lidarr_album_title}"

  log_msg "Pesquisando iTunes (Alvo: ${COVER_SIZE}): $search_term"

  local api_res=$(curl $CURL_OPTS -G --data-urlencode "term=$search_term" \
    "https://itunes.apple.com/search?media=music&entity=album&limit=1")

  # Extrai URL e ajusta resolução
  local img_url=$(echo "$api_res" |
    sed -n 's/.*"artworkUrl100":"\([^"]*\)".*/\1/p' |
    sed "s/100x100bb/${COVER_SIZE}bb/")

  if [[ -z "$img_url" ]]; then
    log_msg "Aviso: Arte não encontrada no iTunes."
    return 1
  fi

  log_msg "Tentando iTunes: $img_url"

  if ! curl $CURL_OPTS -o "$output_file" "$img_url"; then
    log_msg "Erro: Falha no download do iTunes."
    return 1
  fi

  if [[ ! -s "$output_file" ]]; then
    rm -f "$output_file"
    return 1
  fi

  return 0
}

fetch_musicbrainz_cover() {
  local output_file="$1"
  local mbid="$lidarr_albumrelease_mbid"
  local url

  if [[ -z "$mbid" ]]; then
    mbid="$lidarr_album_mbid"
  fi

  if [[ -z "$mbid" ]]; then
    log_msg "Erro: Nenhum MBID disponível para buscar no MusicBrainz."
    return 1
  fi

  # Tenta buscar pelo Release MBID (front-1200 ou original)
  url="https://coverartarchive.org/release/$mbid/front"
  log_msg "Tentando MusicBrainz (Release): $url"

  if curl $CURL_OPTS -f -o "$output_file" "$url"; then
    log_msg "Sucesso: Arte encontrada no MusicBrainz."
    return 0
  fi

  # Se falhar e tiver album_mbid diferente (Release Group), tenta fallback
  if [[ -n "$lidarr_album_mbid" && "$lidarr_album_mbid" != "$mbid" ]]; then
    url="https://coverartarchive.org/release-group/$lidarr_album_mbid/front"
    log_msg "Tentando MusicBrainz (Release Group): $url"
    if curl $CURL_OPTS -f -o "$output_file" "$url"; then
      log_msg "Sucesso: Arte encontrada no MusicBrainz (Release Group)."
      return 0
    fi
  fi

  log_msg "Aviso: Arte não encontrada no MusicBrainz."
  return 1
}

download_artwork() {
  local target_dir="$1"
  local final_cover="${target_dir}/folder.jpg"
  local target_width="${COVER_SIZE%x*}"

  # 0. Verificação de Qualidade Existente (Fast Exit)
  if [[ -f "$final_cover" ]]; then
    local current_width=$(magick identify -format "%w" "$final_cover" 2>/dev/null)
    if [[ -n "$current_width" ]] && ((current_width >= target_width)); then
      log_msg "Qualidade suficiente encontrada (${current_width}px >= ${target_width}px). Pulando busca e embutimento."
      return 2 # Código especial para pular tudo
    fi
  fi

  local cache_key="${lidarr_artist_name}-${lidarr_album_title}"
  local cache_file=$(get_cache_path "$cache_key")

  # 1. Verifica Cache
  if is_cache_valid "$cache_file"; then
    log_msg "Cache válido encontrado para album art."
    cp "$cache_file" "$final_cover"
    return 0
  fi

  local tmp_itunes="${target_dir}/.cover_itunes.tmp"
  local tmp_musicbrainz="${target_dir}/.cover_musicbrainz.tmp"
  local best_original=""
  local got_itunes=0
  local got_musicbrainz=0

  log_msg "Iniciando busca em todas as fontes (Cache Miss)..."

  if fetch_itunes_cover "$tmp_itunes"; then
    got_itunes=1
  fi

  if fetch_musicbrainz_cover "$tmp_musicbrainz"; then
    got_musicbrainz=1
  fi

  if [[ $got_itunes -eq 1 && $got_musicbrainz -eq 1 ]]; then
    local width_itunes=$(magick identify -format "%w" "$tmp_itunes" 2>/dev/null)
    if [[ -z "$width_itunes" ]]; then
      width_itunes=0
    fi

    local width_musicbrainz=$(magick identify -format "%w" "$tmp_musicbrainz" 2>/dev/null)
    if [[ -z "$width_musicbrainz" ]]; then
      width_musicbrainz=0
    fi

    log_msg "Comparando fontes: iTunes (${width_itunes}px) vs MusicBrainz (${width_musicbrainz}px)"

    if ((width_itunes >= width_musicbrainz)); then
      best_original="$tmp_itunes"
      rm -f "$tmp_musicbrainz"
    else
      best_original="$tmp_musicbrainz"
      rm -f "$tmp_itunes"
    fi
  elif [[ $got_itunes -eq 1 ]]; then
    best_original="$tmp_itunes"
  elif [[ $got_musicbrainz -eq 1 ]]; then
    best_original="$tmp_musicbrainz"
  else
    log_msg "Falha: Nenhuma capa encontrada em nenhuma fonte."
    rm -f "$tmp_itunes" "$tmp_musicbrainz"
    return 1
  fi

  # Validação de Resolução Mínima
  local width=$(magick identify -format "%w" "$best_original" 2>/dev/null)
  if [[ -z "$width" ]] || ((width < MIN_WIDTH)); then
    log_msg "Erro: Imagem descartada (Invalida ou < ${MIN_WIDTH}px)."
    rm -f "$best_original"
    return 1
  fi

  if [[ -f "$final_cover" ]]; then
    local old_width=$(magick identify -format "%w" "$final_cover" 2>/dev/null)
    if [[ -z "$old_width" ]]; then
      old_width=0
    fi

    if ((width <= old_width)); then
      log_msg "Aviso: Capa existente é melhor/igual (${old_width}px vs ${width}px)."
      log_msg "Mantendo antiga e atualizando cache."
      cp "$final_cover" "$cache_file"
      rm -f "$best_original"
      return 0
    fi
    log_msg "Nova capa é melhor (${width}px vs ${old_width}px). Atualizando."
  fi

  # Resize e Cache
  log_msg "Processando imagem (Resize para ${COVER_SIZE}) e salvando no cache..."
  magick "$best_original" -resize "${COVER_SIZE}>" -quality 95 "$cache_file"
  rm -f "$best_original"

  if [[ -f "$cache_file" ]]; then
    cp "$cache_file" "$final_cover"
    log_msg "Sucesso: Capa definida."
    return 0
  else
    log_msg "Erro: Falha ao processar imagem."
    return 1
  fi
}

embed_artwork() {
  local target_dir="$1"
  local cover_path="${target_dir}/folder.jpg"
  local track_list

  if [[ ! -f "$cover_path" ]]; then
    return 1
  fi

  log_msg "Embutindo tags in-place com kid3-cli..."

  if [[ -n "$lidarr_addedtrackpaths" ]]; then
    IFS='|' read -r -a track_list <<<"$lidarr_addedtrackpaths"
  elif [[ -n "$lidarr_trackfile_path" ]]; then
    track_list=("$lidarr_trackfile_path")
  fi

  for track in "${track_list[@]}"; do
    if [[ -f "$track" ]]; then
      local kid3_out=$(kid3-cli -c "set picture '' ''" -c "set picture:'$cover_path' ''" "$track" 2>&1)
      if [[ $? -ne 0 ]]; then
        log_msg "Erro ao embutir em: ${track##*/}"
        log_msg "Detalhes kid3: $kid3_out"
      fi
    fi
  done
}

# ==============================================================================
# Início da Execução
# ==============================================================================

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
  log_msg "Nada a fazer."
  log_msg "======================================================================"
  log_msg ""
  exit 0
fi

# 1. Determinar Diretório Alvo
TARGET_DIR=$(get_target_dir)

if [[ -z "$TARGET_DIR" ]] || [[ ! -d "$TARGET_DIR" ]]; then
  log_msg "Erro: Caminho inválido ou não encontrado: $TARGET_DIR"
  exit 0
fi

log_msg ""
log_msg "======================================================================"
log_msg "Evento: $lidarr_eventtype"
if [[ "$lidarr_eventtype" == "TrackRetag" ]]; then
  log_msg "Processando faixa: $lidarr_artist_name - $lidarr_album_title - $lidarr_trackfile_tracktitles"
else
  log_msg "Processando álbum: $lidarr_artist_name - $lidarr_album_title"
fi
log_msg "======================================================================"
log_msg ""

# 2. Orquestração
download_artwork "$TARGET_DIR"
case $? in
0) # Sucesso, prosseguir para embutir
  embed_artwork "$TARGET_DIR"
  ;;
1) # Falha total
  log_msg "Aviso: Nenhuma imagem processada."
  ;;
2) # Skip (Qualidade já atingida)
  log_msg "Aviso: Imagem atual possui boa qualidade. Pulando processamento."
  ;;
esac

exit 0
