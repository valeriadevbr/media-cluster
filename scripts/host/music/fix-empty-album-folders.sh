#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
set +a

echo "Buscando pastas de álbum sem arquivos de mídia em ${MEDIA_PATH}/Music..."

find "${MEDIA_PATH}/Music" -type d -print0 | while IFS= read -r -d '' d; do
  if [ -n "$(find "$d" -mindepth 1 -maxdepth 1 -type d)" ]; then
    continue
  fi
  if [ -z "$(find "$d" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.ogg" -o -iname "*.wma" -o -iname "*.wav" -o -iname "*.opus" \) -print -quit)" ]; then
    echo "--------------------------------------------------"
    echo "📁 $d"
    ls -F "$d" | sed 's/^/  /'
    read -p "Deseja excluir esta pasta? (s/N): " -n 1 -r </dev/tty
    echo ""
    if [[ $REPLY =~ ^[Ss]$ ]]; then
      rm -rf "$d"
      echo "✅ Pasta excluída."
    else
      echo "⏸️  Pasta mantida."
    fi
  fi
done
