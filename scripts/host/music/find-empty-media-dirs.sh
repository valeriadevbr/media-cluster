#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
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

echo "Buscando diretórios sem arquivos MP3, FLAC ou OGG em: ${DIRS[*]}..."
echo "------------------------------------------------------------"

find "${DIRS[@]}" -type d -print0 | while IFS= read -r -d '' d; do
  if ! find "$d" -maxdepth 10 -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" \) | grep -q .; then
    echo "$d"
  fi
done
