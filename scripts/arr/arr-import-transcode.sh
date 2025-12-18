#!/bin/bash

# Script de importação otimizado para Sonarr/Radarr (Modo Import Using Script)
# Usa argumentos posicionais: $1 (origem) e $2 (destino)

# ================================================
# Configurações e Globais
# ================================================

export PATH="$PATH:/opt/homebrew/bin"

KEEP_LANGS="${KEEP_LANGS:-por,eng}"
LOG_FILE="/tmp/arr-import-transcode.log"

# ================================================
# Funções Auxiliares (Baseadas no arr-transcode.sh)
# ================================================

log_msg() {
  local msg="$1"
  local ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
  echo "$ts $msg" | tee -a "$LOG_FILE"
}

check_dependencies() {
  for cmd in mkvmerge jq; do
    if ! command -v "$cmd" &>/dev/null; then
      log_msg "❌ Erro: Dependência '$cmd' não encontrada no PATH."
      exit 1
    fi
  done
}

get_subtitles_to_remove() {
  local file="$1"
  local langs_3c=()
  local langs_ietf=()
  IFS=',' read -ra langs <<<"$KEEP_LANGS"
  for lang in "${langs[@]}"; do
    lang_lower=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
    [[ ${#lang_lower} -eq 3 ]] && langs_3c+=("$lang_lower") || langs_ietf+=("$lang_lower")
  done
  local jq_filter=".tracks[] | select(.type == \"subtitles\")"
  local conditions=()
  if [[ ${#langs_3c[@]} -gt 0 ]]; then
    local lang_condition=""
    for lang in "${langs_3c[@]}"; do
      [[ -z "$lang_condition" ]] && lang_condition="(.properties.language // \"\" | ascii_downcase) != \"$lang\"" || lang_condition="$lang_condition and (.properties.language // \"\" | ascii_downcase) != \"$lang\""
    done
    conditions+=("($lang_condition)")
  fi
  if [[ ${#langs_ietf[@]} -gt 0 ]]; then
    local ietf_condition=""
    for lang in "${langs_ietf[@]}"; do
      [[ -z "$ietf_condition" ]] && ietf_condition="(.properties.language_ietf // \"\" | ascii_downcase) != \"$lang\"" || ietf_condition="$ietf_condition and (.properties.language_ietf // \"\" | ascii_downcase) != \"$lang\""
    done
    conditions+=("($ietf_condition)")
  fi
  if [[ ${#conditions[@]} -eq 2 ]]; then
    jq_filter="$jq_filter | select(${conditions[0]} and ${conditions[1]})"
  elif [[ ${#conditions[@]} -eq 1 ]]; then
    jq_filter="$jq_filter | select(${conditions[0]})"
  fi
  jq_filter="$jq_filter | select(.properties.language != null and .properties.language != \"unknown\")"
  jq_filter="$jq_filter | \"\\(.id):\\(.properties.language // \"\"):\\(.properties.track_name // \"\")\""
  mkvmerge -J "$file" | jq -r "$jq_filter"
}

log_kept_tracks() {
  local input_file="$1"
  local kept_tracks_ids=$(get_track_ids_by_type "$input_file" "subtitles" "keep")
  if [[ -n "$kept_tracks_ids" ]]; then
    log_msg ""
    log_msg "Faixas de legenda mantidas:"
    local info_json=$(mkvmerge -J "$input_file" 2>/dev/null)
    for tid in $kept_tracks_ids; do
      local lang=$(echo "$info_json" | jq -r ".tracks[] | select(.id==$tid and .type==\"subtitles\") | .properties.language // \"\"")
      local name=$(echo "$info_json" | jq -r ".tracks[] | select(.id==$tid and .type==\"subtitles\") | .properties.track_name // \"\"")
      if [[ -n "$lang" && "$lang" != "null" ]]; then
        [[ -n "$name" && "$name" != "null" && "$name" != "unknown" ]] && log_msg "  - Faixa $tid: $lang ($name)" || log_msg "  - Faixa $tid: $lang"
      else
        log_msg "  - Faixa $tid: (sem linguagem especificada)"
      fi
    done
  else
    log_msg "Nenhuma faixa de legenda será mantida."
  fi
}

log_removed_tracks() {
  local input_file="$1"
  local subs_to_remove=$(get_subtitles_to_remove "$input_file")
  log_msg ""
  log_msg "Faixas de legenda a remover:"
  if [[ -n "$subs_to_remove" ]]; then
    while IFS=: read -r track_id language track_name; do
      if [[ -n "$track_id" && "$track_id" =~ ^[0-9]+$ ]]; then
        [[ -n "$track_name" && "$track_name" != "unknown" && "$track_name" != "" ]] && log_msg "  - Faixa $track_id: $language ($track_name)" || log_msg "  - Faixa $track_id: $language"
      fi
    done <<<"$subs_to_remove"
  fi
}

get_track_ids_by_type() {
  local file="$1"
  local track_type="$2"
  local language_filter="$3"

  if [[ "$language_filter" == "keep" ]]; then
    local langs_3c=()
    local langs_ietf=()
    IFS=',' read -ra keep_array <<<"$KEEP_LANGS"
    for lang in "${keep_array[@]}"; do
      lang_lower=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
      if [[ ${#lang_lower} -eq 3 ]]; then
        langs_3c+=("$lang_lower")
      elif [[ ${#lang_lower} -ge 2 ]]; then
        langs_ietf+=("$lang_lower")
      fi
    done

    local jq_filter=".tracks[] | select(.type == \"$track_type\")"
    local conditions=()

    if [[ ${#langs_3c[@]} -gt 0 ]]; then
      local lang_condition=""
      for lang in "${langs_3c[@]}"; do
        if [[ -z "$lang_condition" ]]; then
          lang_condition="(.properties.language // \"\" | ascii_downcase) == \"$lang\""
        else
          lang_condition="$lang_condition or (.properties.language // \"\" | ascii_downcase) == \"$lang\""
        fi
      done
      conditions+=("($lang_condition)")
    fi

    if [[ ${#langs_ietf[@]} -gt 0 ]]; then
      local ietf_condition=""
      for lang in "${langs_ietf[@]}"; do
        if [[ -z "$ietf_condition" ]]; then
          ietf_condition="(.properties.language_ietf // \"\" | ascii_downcase) == \"$lang\""
        else
          ietf_condition="$ietf_condition or (.properties.language_ietf // \"\" | ascii_downcase) == \"$lang\""
        fi
      done
      conditions+=("($ietf_condition)")
    fi

    if [[ ${#conditions[@]} -eq 2 ]]; then
      jq_filter="$jq_filter | select(${conditions[0]} or ${conditions[1]})"
    elif [[ ${#conditions[@]} -eq 1 ]]; then
      jq_filter="$jq_filter | select(${conditions[0]})"
    else
      jq_filter="$jq_filter | select(false)"
    fi

    jq_filter="$jq_filter | select(.properties.language != null and .properties.language != \"unknown\")"
    jq_filter="$jq_filter | \"\\(.id)\""

    mkvmerge -J "$file" | jq -r "$jq_filter"
  else
    mkvmerge -J "$file" | jq -r --arg type "$track_type" '
            .tracks[] |
            select(.type == $type) |
            "\(.id)"
        '
  fi
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

# 2. Construir Comando MKVMerge
log_kept_tracks "$INPUT_FILE"
log_removed_tracks "$INPUT_FILE"

VIDEO_TRACKS=$(get_track_ids_by_type "$INPUT_FILE" "video" "all" | tr '\n' ',' | sed 's/,$//')
AUDIO_TRACKS=$(get_track_ids_by_type "$INPUT_FILE" "audio" "all" | tr '\n' ',' | sed 's/,$//')
SUB_TRACKS=$(get_track_ids_by_type "$INPUT_FILE" "subtitles" "keep" | tr '\n' ',' | sed 's/,$//')

MKV_CMD="nice -n 19 mkvmerge -o \"$OUTPUT_FILE\""
[[ -n "$VIDEO_TRACKS" ]] && MKV_CMD="$MKV_CMD -d $VIDEO_TRACKS" || MKV_CMD="$MKV_CMD -D"
[[ -n "$AUDIO_TRACKS" ]] && MKV_CMD="$MKV_CMD -a $AUDIO_TRACKS" || MKV_CMD="$MKV_CMD -A"
[[ -n "$SUB_TRACKS" ]]   && MKV_CMD="$MKV_CMD -s $SUB_TRACKS"   || MKV_CMD="$MKV_CMD -S"
MKV_CMD="$MKV_CMD \"$INPUT_FILE\""

# 3. Execução
mkdir -p "$(dirname "$OUTPUT_FILE")"
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
