#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
set +a

# Caminho da biblioteca de música
MUSIC_DIR="${MEDIA_PATH}/Music"

if [[ ! -d "$MUSIC_DIR" ]]; then
  echo "ERRO: Diretório de música não encontrado: $MUSIC_DIR"
  exit 1
fi

echo "Criando hardlinks (artist.jpg -> folder.jpg) em: $MUSIC_DIR"

find "$MUSIC_DIR" -maxdepth 2 -name "artist.jpg" -execdir ln -f artist.jpg folder.jpg \;

echo "Concluído."
