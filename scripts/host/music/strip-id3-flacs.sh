#!/bin/bash
set -e

TARGET_DIR="$1"

if [[ -z "$TARGET_DIR" || ! -d "$TARGET_DIR" ]]; then
  echo "Uso: $0 <diretorio_musica>"
  exit 1
fi

echo "Iniciando varredura recursiva por ID3v2 em: $TARGET_DIR..."

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

done < <(find "$TARGET_DIR" -type f -name "*.flac" -print0 | sort -z)

echo "--------------------------------------"
echo "Concluído! Total: $TOTAL_FILES | Limpos: $CLEANED_COUNT | Pulados: $SKIPPED_COUNT"
