#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
set +a

echo "Buscando pastas de música sem folder.jpg..."

find "${MEDIA_PATH}/Music" -type d -print0 | while IFS= read -r -d '' d; do
  if [ -n "$(find "$d" -mindepth 1 -maxdepth 1 -type d)" ]; then
    continue
  fi
  if [ -f "$d/folder.jpg" ]; then
    continue
  fi

  music_file=$(find "$d" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.ogg" -o -iname "*.wma" -o -iname "*.wav" \) | head -n 1)

  if [ -n "$music_file" ] &&
    ffmpeg -nostdin -i "$music_file" -an -vcodec copy "$d/folder.jpg" -y -loglevel error >/dev/null 2>&1 &&
    [ -s "$d/folder.jpg" ]; then
    echo "$d OK"
  else
    rm -f "$d/folder.jpg"
    echo "$d KO"
  fi
done
