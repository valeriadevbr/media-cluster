#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
. "$(dirname -- "$0")/../../../setup/includes/pkg-utils.sh"
set +a

if [ $# -gt 0 ]; then
  DIRS=("$@")
else
  DIRS=("${MEDIA_PATH}/Music")
fi

for dir in "${DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "ERRO: Diretório não encontrado: $dir" >&2
    exit 1
  fi
done

install_sys_pkg "flac"

UNIX_TIME=$(date +%s)
CSV_FILE="./albums_missing_md5-${UNIX_TIME}.csv"

echo '"Artista","Album","Tipo de Mídia"' >"$CSV_FILE"

get_tag() {
  local tag=$1
  local file=$2
  metaflac --show-tag="$tag" "$file" | head -n 1 | sed 's/^.*=//'
}

escape_csv() {
  echo "$1" | sed 's/"/""/g'
}

echo "Iniciando busca por álbuns com faixas sem MD5 em: ${DIRS[*]}..."

LAST_DIR=""
SKIP_DIR=0

while IFS= read -r -d '' file; do
  CURRENT_DIR=$(dirname "$file")

  if [[ "$CURRENT_DIR" == "$LAST_DIR" ]] && [[ $SKIP_DIR -eq 1 ]]; then
    continue
  fi

  if [[ "$CURRENT_DIR" != "$LAST_DIR" ]]; then
    SKIP_DIR=0
    LAST_DIR="$CURRENT_DIR"
  fi

  MD5=$(metaflac --show-md5sum "$file")

  if [[ -z "$MD5" ]] || [[ "$MD5" =~ ^0+$ ]]; then
    ARTIST=$(get_tag "ARTIST" "$file")
    ALBUM=$(get_tag "ALBUM" "$file")
    MEDIA=$(get_tag "MEDIA" "$file")
    DISC=$(get_tag "DISCNUMBER" "$file")

    if [[ -z "$ARTIST" ]]; then ARTIST="Artista Desconhecido"; fi
    if [[ -z "$ALBUM" ]]; then ALBUM="$(basename "$CURRENT_DIR")"; fi

    MEDIA_COMBINED=$(echo "${MEDIA} ${DISC}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [[ -z "$MEDIA_COMBINED" ]]; then MEDIA_COMBINED="Desconhecido"; fi

    E_ARTIST=$(escape_csv "$ARTIST")
    E_ALBUM=$(escape_csv "$ALBUM")
    E_MEDIA=$(escape_csv "$MEDIA_COMBINED")

    echo "\"$E_ARTIST\",\"$E_ALBUM\",\"$E_MEDIA\"" >>"$CSV_FILE"
    echo -e "\033[1;33mEncontrado:\033[0m $E_ARTIST - $E_ALBUM [$E_MEDIA]"

    SKIP_DIR=1
  fi

done < <(find "${DIRS[@]}" -type f -name "*.flac" -print0 | sort -z)

echo "Busca concluída. Resultados salvos em $CSV_FILE"
