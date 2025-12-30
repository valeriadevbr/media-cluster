#!/bin/bash

# ==============================================================================
# Lidarr Lyrics Cleaner (clean-unsynced-lyrics.sh)
#
# Este script varre a biblioteca de música e remove (ou reporta) as letras
# que NÃO possuem timestamps (letras não sincronizadas ou lixo).
#
# Uso:
#   ./clean-unsynced-lyrics.sh [caminho_base] [--dry-run]
#
#   caminho_base: O diretório para varrer (padrão: /media/Music)
#   --dry-run:    Apenas lista os arquivos afetados sem alterar nada.
# ==============================================================================

SEARCH_DIR="${1:-/media/Music}"
DRY_RUN=false

if [[ "$2" == "--dry-run" ]] || [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  if [[ "$1" == "--dry-run" ]]; then SEARCH_DIR="/media/Music"; fi
fi

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

if ! command -v kid3-cli >/dev/null 2>&1; then
  log_msg "ERRO: kid3-cli não encontrado."
  exit 1
fi

log_msg "Iniciando varredura em: $SEARCH_DIR"
if [[ "$DRY_RUN" == "true" ]]; then
  log_msg "MODO DRY-RUN: Nenhuma alteração será feita."
fi

count_total=0
count_affected=0

# Loop através de arquivos de áudio (flac, mp3, m4a)
while read -r file; do
  ((count_total++))

  # Lê a letra, ignorando erros do GStreamer
  lyrics=$(kid3-cli -c "get lyrics" "$file" 2>/dev/null | grep -v "Failed to create")

  # Se tem letra...
  if [[ -n "$lyrics" ]]; then
    # Remove espaços em branco para checar se é vazia mesmo
    trimmed_lyrics=$(echo "$lyrics" | tr -d '[:space:]')
    if [[ -z "$trimmed_lyrics" ]]; then
      continue
    fi
    # Verifica se contém timestamp (formato [mm:ss.xx] ou [mm:ss])
    if ! echo "$lyrics" | grep -qE "\[[0-9]{2}:[0-9]{2}(\.[0-9]{2,3})?\]"; then
      ((count_affected++))

      log_msg "Encontrado (Sem Timestamp): $file"
      # Opcional: Mostrar preview do começo da letra ruim
      # echo "$lyrics" | head -n 3 | sed 's/^/    >> /'

      if [[ "$DRY_RUN" == "false" ]]; then
        # Remove a letra
        kid3-cli -c "set lyrics ''" "$file"
        if [[ $? -eq 0 ]]; then
          echo "    -> Letra removida com sucesso."
        else
          echo "    -> ERRO ao remover letra."
        fi
      else
        echo "    -> (Dry Run) Letra seria removida."
      fi
    fi
  fi

  # Feedback visual a cada 100 arquivos
  if ((count_total % 100 == 0)); then
    echo -ne "Processados: $count_total...\r" >&2
  fi
done < <(find "$SEARCH_DIR" -type f \( -name "*.flac" -o -name "*.mp3" -o -name "*.m4a" \))

log_msg "Varredura concluída."
log_msg "Total processado: $count_total"
log_msg "Arquivos sem timestamps (afetados): $count_affected"
