#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
. "$(dirname -- "$0")/../../../setup/includes/pkg-utils.sh"
set +a

if [ $# -eq 0 ]; then
  echo "Uso: $0 <caminho_musica_ou_diretorio> [caminhos...]"
  exit 1
fi
PATHS=("$@")

for p in "${PATHS[@]}"; do
  if [[ ! -e "$p" ]]; then
    echo "ERRO: Caminho não encontrado: $p"
    exit 1
  fi
done

echo "Iniciando varredura por ID3 em: ${PATHS[*]}..."

TOTAL_FILES=0
CLEANED_COUNT=0
SKIPPED_COUNT=0

while IFS= read -r -d '' file; do
  ((TOTAL_FILES++))
  CLEANED_V1=false
  CLEANED_V2=false

  HEADER=$(head -c 3 "$file")
  FOOTER=$(tail -c 128 "$file" | head -c 3)

  if [[ "$HEADER" == "ID3" || "$FOOTER" == "TAG" ]]; then
    TEMP_FILE="${file}.tmp.flac"

    if [[ "$HEADER" == "ID3" && "$FOOTER" == "TAG" ]]; then
      echo "⚠️  DETECTADO ID3v1 & v2: $file"
    elif [[ "$HEADER" == "ID3" ]]; then
      echo "⚠️  DETECTADO ID3v2: $file"
    else
      echo "⚠️  DETECTADO ID3v1: $file"
    fi

    if [[ "$HEADER" == "ID3" ]]; then
      if ffmpeg -v error -i "$file" -c copy -map_metadata 0 "$TEMP_FILE" -y </dev/null; then
        mv "$TEMP_FILE" "$file"
        CLEANED_V2=true
      else
        echo "❌ ERRO AO LIMPAR ID3v2: $file"
        rm -f "$TEMP_FILE"
      fi
    fi

    FOOTER=$(tail -c 128 "$file" | head -c 3)
    if [[ "$FOOTER" == "TAG" ]]; then
      if perl -e 'truncate $ARGV[0], (stat $ARGV[0])[7] - 128' "$file"; then
        CLEANED_V1=true
      else
        echo "❌ ERRO AO TRUNCAR ID3v1: $file"
      fi
    fi

    if [[ "$CLEANED_V1" == true || "$CLEANED_V2" == true ]]; then
      echo "✅ LIMPO$([[ "$CLEANED_V1" == true ]] && echo " (ID3v1)")$([[ "$CLEANED_V2" == true ]] && echo " (ID3v2)")"
      ((CLEANED_COUNT++))
    fi
  else
    ((SKIPPED_COUNT++))
  fi

done < <(find "${PATHS[@]}" -type f -name "*.flac" -print0 | sort -z)

echo "--------------------------------------"
echo "Concluído! Total: $TOTAL_FILES | Limpos: $CLEANED_COUNT | Pulados: $SKIPPED_COUNT"
