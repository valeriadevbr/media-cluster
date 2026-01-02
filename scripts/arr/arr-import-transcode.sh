#!/bin/bash

# Script de importação otimizado para Sonarr/Radarr (Modo Import Using Script)
# Usa argumentos posicionais: $1 (origem) e $2 (destino)

# ================================================
# Configurações e Globais
# ================================================

export PATH="$PATH:/opt/homebrew/bin"

KEEP_LANGS="${KEEP_LANGS:-por,eng}"
LOG_FILE="/tmp/arr-import-transcode.log"

if [[ ! -f "$LOG_FILE" ]]; then
  touch "$LOG_FILE"
  if [[ -n "$PUID" && -n "$PGID" ]]; then
    chown "${PUID}:${PGID}" "$LOG_FILE" 2>/dev/null || true
  fi
  chmod 666 "$LOG_FILE"
fi

exec 3>&1

# ================================================
# Funções Auxiliares (Baseadas no arr-transcode.sh)
# ================================================

log_msg() {
  local msg="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] %s\n" "$timestamp" "$msg" | tee -a "$LOG_FILE" >&3
}

check_dependencies() {
  for cmd in mkvmerge jq; do
    if ! command -v "$cmd" &>/dev/null; then
      log_msg "❌ Erro: Dependência '$cmd' não encontrada no PATH."
      exit 1
    fi
  done
}

# ================================================
# Lógica Principal
# ================================================

INPUT_FILE="$1"
OUTPUT_FILE="$2"

# 1. Validação de Argumentos
if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
  log_msg "❌ Erro: Uso incorreto. Esperado: $0 <source_path> <dest_path>"
  exit 1
fi

log_msg "----------------------------------------------------"
log_msg "🚀 Iniciando importação com transcode..."
log_msg "   Fonte: $INPUT_FILE"
log_msg "   Destino: $OUTPUT_FILE"

check_dependencies

if [[ ! -f "$INPUT_FILE" ]]; then
  log_msg "❌ Erro: Arquivo de origem não encontrado."
  exit 2
fi

# 2. Análise de Faixas (Single Pass)
log_msg "🔍 Analisando faixas..."

# Prepara lista de idiomas permitidos para o JQ
IFS=',' read -ra LANGS_ARRAY <<<"$KEEP_LANGS"
JSON_LANGS=$(printf '%s\n' "${LANGS_ARRAY[@]}" | jq -R . | jq -s 'map(ascii_downcase)')

# Extrai metadados de TODAS as faixas de áudio e legenda de uma vez
# Formato de saída por linha: ID|TYPE|LANG|IETF|NAME|IS_PREFERRED
TRACKS_DATA=$(mkvmerge -J "$INPUT_FILE" | jq -r --argjson langs "$JSON_LANGS" '
  .tracks[]
  | select(.type == "audio" or .type == "subtitles")
  | . as $t
  | (.properties.language // "") as $lang
  | (.properties.language_ietf // "") as $ietf
  | (($lang | ascii_downcase) as $l | $l | IN($langs[])) or
    (($ietf | ascii_downcase) as $i | $i | IN($langs[])) as $is_pref
  | [ $t.id, $t.type, $lang, $ietf, ($t.properties.track_name // ""), $is_pref ]
  | @tsv
')

# Arrays para armazenar decisões
declare -a audio_all audio_keep audio_logs
declare -a sub_all sub_keep sub_logs

# Processa linha a linha a saída do JQ
while IFS=$'\t' read -r id type lang ietf name is_pref; do
  # Formata nome para log: language language_ietf (track_name)
  display_name="${lang}"
  [[ -n "$ietf" ]] && display_name="${display_name}/${ietf}"
  [[ -n "$name" ]] && display_name="${display_name} (${name})"

  if [[ "$type" == "audio" ]]; then
    audio_all+=("$id")
    if [[ "$is_pref" == "true" ]]; then
      audio_keep+=("$id")
      audio_logs+=("  - [MANTIDO] Faixa $id: $display_name")
    else
      audio_logs+=("  - [REMOVIDO] Faixa $id: $display_name")
    fi
  elif [[ "$type" == "subtitles" ]]; then
    sub_all+=("$id")
    if [[ "$is_pref" == "true" ]]; then
      sub_keep+=("$id")
      sub_logs+=("  - [MANTIDO] Faixa $id: $display_name")
    else
      sub_logs+=("  - [REMOVIDO] Faixa $id: $display_name")
    fi
  fi
done <<<"$TRACKS_DATA"

# 3. Lógica de Fallback de Áudio
# Se havia áudio, mas nenhum foi selecionado (nenhum match de idioma), mantém TODOS.
if [[ ${#audio_all[@]} -gt 0 && ${#audio_keep[@]} -eq 0 ]]; then
  log_msg "⚠️  Aviso: Nenhum áudio corresponde aos idiomas preferidos ($KEEP_LANGS)."
  log_msg "   -> ATIVANDO FALLBACK: Mantendo todas as faixas de áudio para evitar arquivo mudo."

  # Reseta lista de keep para all
  audio_keep=("${audio_all[@]}")

  # Regenera logs de áudio para refletir a decisão
  audio_logs=()
  while IFS=$'\t' read -r id type lang ietf name is_pref; do
    if [[ "$type" == "audio" ]]; then
      display_name="${lang}"
      [[ -n "$ietf" ]] && display_name="${display_name}/${ietf}"
      [[ -n "$name" ]] && display_name="${display_name} (${name})"
      audio_logs+=("  - [FALLBACK] Faixa $id: $display_name")
    fi
  done <<<"$TRACKS_DATA"
fi

# 4. Exibe Logs Agrupados e Ordenados
if [[ ${#audio_logs[@]} -gt 0 ]]; then
  log_msg "🔊 Áudio:"
  printf "%s\n" "${audio_logs[@]}" | sort -k 2,2 -k 5
fi

if [[ ${#sub_logs[@]} -gt 0 ]]; then
  log_msg "💬 Legendas:"
  printf "%s\n" "${sub_logs[@]}" | sort -k 2,2 -k 5
fi

# 5. Constrói Comando Final
VIDEO_TRACKS=$(mkvmerge -J "$INPUT_FILE" | jq -r '.tracks[] | select(.type=="video") | .id' | tr '\n' ',' | sed 's/,$//')
AUDIO_IDS=$(
  IFS=,
  echo "${audio_keep[*]}"
)
SUB_IDS=$(
  IFS=,
  echo "${sub_keep[*]}"
)

MKV_CMD="nice -n 19 mkvmerge -o \"$OUTPUT_FILE\""
[[ -n "$VIDEO_TRACKS" ]] && MKV_CMD="$MKV_CMD -d $VIDEO_TRACKS" || MKV_CMD="$MKV_CMD -D"
[[ -n "$AUDIO_IDS" ]] && MKV_CMD="$MKV_CMD -a $AUDIO_IDS" || MKV_CMD="$MKV_CMD -A"
[[ -n "$SUB_IDS" ]] && MKV_CMD="$MKV_CMD -s $SUB_IDS" || MKV_CMD="$MKV_CMD -S"
MKV_CMD="$MKV_CMD \"$INPUT_FILE\""

# 6. Execução
mkdir -p "$(dirname "$OUTPUT_FILE")"
log_msg ""
log_msg "⚙️  Executando mkvmerge..."

eval "$MKV_CMD"
RESULT=$?

if [[ $RESULT -eq 0 && -f "$OUTPUT_FILE" && -s "$OUTPUT_FILE" ]]; then
  log_msg "✅ Sucesso! Arquivo gerado em: $OUTPUT_FILE"
  exit 0
else
  log_msg "❌ Erro: mkvmerge falhou ou gerou arquivo inválido (Code: $RESULT)"
  [[ -f "$OUTPUT_FILE" ]] && rm -f "$OUTPUT_FILE"
  exit 6
fi
