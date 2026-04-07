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
    echo "ERRO: Diretório não encontrado: $dir"
    exit 1
  fi
done

install_sys_pkg "flac"

TMP_ERROR_LOG="/tmp/flac_error.log"
LOG_FILE="./flac_validation.log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

>"$LOG_FILE"

DAMAGED_COUNT=0
UNVERIFIABLE_COUNT=0
TOTAL_FILES=0

echo "Iniciando verificação recursiva em: ${DIRS[*]}..."

while IFS= read -r -d '' file; do
  ((TOTAL_FILES++))
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  FULL_PATH="$(realpath "$file")"

  if ! flac -t --silent "$file" 2>"$TMP_ERROR_LOG"; then
    ERROR_MSG=$(head -n 1 "$TMP_ERROR_LOG" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    echo -e "${RED}${TIMESTAMP}\t❌\tKO\t${FULL_PATH}\t${ERROR_MSG}${NC}"
    echo -e "${TIMESTAMP}\t❌\tKO\t${FULL_PATH}\t${ERROR_MSG}" >>"$LOG_FILE"
    ((DAMAGED_COUNT++))
    continue
  fi

  MD5=$(metaflac --show-md5sum "$file")
  if [[ "$MD5" =~ ^0+$ ]] || [[ -z "$MD5" ]]; then
    echo -e "${YELLOW}${TIMESTAMP}\t⚠️\tNOMD5\t${FULL_PATH}${NC}"
    echo -e "${TIMESTAMP}\t⚠️\tNOMD5\t${FULL_PATH}" >>"$LOG_FILE"
    ((UNVERIFIABLE_COUNT++))
  else
    echo -e "${GREEN}${TIMESTAMP}\t✅\tOK\t${FULL_PATH}${NC}"
  fi

done < <(find "${DIRS[@]}" -type f -name "*.flac" -print0 | sort -z)

echo "--------------------------------------"
echo "Concluído! Total: $TOTAL_FILES | Danificados: $DAMAGED_COUNT | Sem MD5: $UNVERIFIABLE_COUNT"

if [ "$DAMAGED_COUNT" -gt 0 ]; then
  exit 1
fi
