#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
. "$(dirname -- "$0")/../../../setup/includes/pkg-utils.sh"
set +a

TMP_FILE=""
cleanup() {
  if [[ -n "$TMP_FILE" && -f "$TMP_FILE" ]]; then
    rm -f "$TMP_FILE"
  fi
}
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap cleanup EXIT

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
ORANGE='\033[38;5;208m'
NC='\033[0m'

escape_csv() {
  echo "$1" | sed 's/"/""/g'
}

LOG_FILE=""
while getopts "o:" opt; do
  case $opt in
  o) LOG_FILE="$OPTARG" ;;
  *)
    echo "Uso: $0 [-o log_file] [diretorios...]" >&2
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -gt 0 ]; then
  DIRS=("$@")
else
  DIRS=("${MEDIA_PATH}/Music")
fi

for dir in "${DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo -e "${RED}ERRO: Diretório não encontrado: $dir${NC}" >&2
    exit 1
  fi
done

install_sys_pkg "flac"

if [[ -n "$LOG_FILE" ]]; then
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "Estado,MD5,Caminho" >"$LOG_FILE"
fi

printf "%-22s %-10s %-33s %s\n" "TIMESTAMP" "ESTADO" "MD5" "CAMINHO"
echo "-------------------------------------------------------------------------------------------------"

while IFS= read -r -d '' file; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  MD5=$(metaflac --show-md5sum "$file")
  STATE=""
  COLOR=""

  if [[ -z "$MD5" ]] || [[ "$MD5" =~ ^0+$ ]]; then
    if flac -t --silent "$file" 2>/dev/null; then
      TMP_FILE="${file}.tmp.$$.flac"
      if flac -o "$TMP_FILE" --preserve-modtime --verify --best "$file" &>/dev/null; then
        mv "$TMP_FILE" "$file"
        TMP_FILE=""
        STATE="FIXED"
        COLOR=$ORANGE
        MD5=$(metaflac --show-md5sum "$file")
      else
        [ $? -eq 130 ] && exit 130
        rm -f "$TMP_FILE"
        TMP_FILE=""
        STATE="ERROR"
        COLOR=$RED
      fi
    else
      [ $? -eq 130 ] && exit 130
      STATE="DAMAGED"
      COLOR=$RED
    fi
  else
    if flac -t --silent "$file" 2>/dev/null; then
      STATE="VALID"
      COLOR=$GREEN
    else
      [ $? -eq 130 ] && exit 130
      STATE="DAMAGED"
      COLOR=$RED
    fi
  fi

  printf "%-22s %b%-10s%b %-33s %s\n" "$TIMESTAMP" "$COLOR" "$STATE" "$NC" "$MD5" "$file"

  if [[ -n "$LOG_FILE" ]]; then
    E_FILE=$(escape_csv "$file")
    echo "\"$STATE\",\"$MD5\",\"$E_FILE\"" >>"$LOG_FILE"
  fi

done < <(find "${DIRS[@]}" -type f -name "*.flac" -print0 | sort -z)
