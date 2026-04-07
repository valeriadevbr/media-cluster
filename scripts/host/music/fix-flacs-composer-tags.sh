#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
set +a

MUSIC_DIR="${MEDIA_PATH}/Music"

if [[ ! -d "$MUSIC_DIR" ]]; then
  echo "ERRO: Diretório de música não encontrado: $MUSIC_DIR"
  exit 1
fi

DRY_RUN=0
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN=1
    shift
    ;;
  -*)
    echo "ERRO: Parâmetro não reconhecido: $1"
    echo "Uso: $0 [--dry-run] [caminho...]"
    exit 1
    ;;
  *)
    PATHS+=("$1")
    shift
    ;;
  esac
done

if [ ${#PATHS[@]} -eq 0 ]; then
  PATHS=("${MEDIA_PATH}/Music")
fi

for p in "${PATHS[@]}"; do
  if [[ ! -e "$p" ]]; then
    echo "ERRO: Caminho não encontrado: $p"
    exit 1
  fi
done

echo "Iniciando processamento de FLACs em: ${PATHS[*]}"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "MODO DRY-RUN: Nenhuma alteração será feita nos arquivos."
fi

process_file() {
  local music_file="$1"

  if [[ "${music_file##*.}" != "flac" ]]; then
    return
  fi

  local original_composers=$(metaflac --show-tag=COMPOSER "$music_file" |
    sed -E 's/^COMPOSER=//i' || true)

  if [[ -z "$original_composers" ]]; then
    return
  fi

  local original_composers_clean=$(echo "$original_composers" |
    sed -E 's/,[[:space:]]*([Jj][Rr]\.?)/ \1/g')

  local new_composers=$(echo "$original_composers_clean" |
    awk -F '[&,/]' '{for(i=1;i<=NF;i++) print $i}' |
    sed -E 's/^[[:space:]]+|[[:space:]]+$//g' |
    sed -E 's/[[:space:]]{2,}/ /g' | grep -v '^$' || true)

  local num_original=$(echo "$original_composers" | grep -c . || echo 0)
  local num_new=$(echo "$new_composers" | grep -c . || echo 0)

  if (echo "$original_composers_clean" | grep -q "[&,/]") ||
    [ "$num_new" -gt "$num_original" ] ||
    [[ "$original_composers" != "$original_composers_clean" ]]; then

    local relative_path="${music_file#"$MUSIC_DIR/"}"
    local original_log=$(echo "$original_composers" | \
      tr '\n' ' ' | sed 's/  */ /g')
    local new_log=$(echo "$new_composers" | \
      tr '\n' ';' | sed 's/;$//' | sed 's/;/; /g')

    echo "$relative_path: $original_log -> $new_log"

    if [ "$DRY_RUN" -eq 0 ]; then
      local cmd=("metaflac" "--remove-tag=COMPOSER")
      local p
      while read -r p; do
        if [[ -n "$p" ]]; then
          cmd+=("--set-tag=COMPOSER=$p")
        fi
      done <<<"$new_composers"
      cmd+=("$music_file")

      "${cmd[@]}"
    fi
  fi
}

find "${PATHS[@]}" -type f -iname "*.flac" -print0 | sort -z |
  while IFS= read -r -d '' music_file; do
    process_file "$music_file"
  done

echo "Concluído."
