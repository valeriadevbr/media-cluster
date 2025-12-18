#!/bin/bash

# Script de importação para Remove legendas não-desejadas de arquivos MKV
# Modo *Arr: Variáveis de ambiente do servidor
# Modo CLI: Argumentos de linha de comando (-in, -out)

# Exit codes do script:
# 0  - Sucesso
# 1  - Parâmetro inválido (CLI ou ENV)
# 2  - Arquivo não encontrado
# 3  - Dependência ou erro de processamento
# 4  - Erro ao copiar arquivo
# 5  - Arquivo não é MKV ou MP4
# 6  - Falha na execução do mkvmerge
# 10+ - Outros erros específicos

# ================================================
# Variáveis Globais
# ================================================

# Garante que os binários do Homebrew estejam no PATH em eventuais subshells
export PATH="$PATH:/opt/homebrew/bin"

# Variáveis internas (preenchidas por ENV ou CLI)
CURRENT_NEW_FILE=""
DRY_RUN=false
INTERRUPTED=false
KEEP_LANGS="${KEEP_LANGS:-por,eng}"
LOG_FILE="${LOG_FILE:-/tmp/arr_transcode.log}"
LOG_TO_FILE=false

# *Arr Server
EVENT_TYPE="${sonarr_eventtype:-$radarr_eventtype}"
SOURCE_PATH="${sonarr_episodefile_sourcepath:-$radarr_moviefile_sourcepath}"
OUTPUT_PATH="${sonarr_episodefile_path:-$radarr_moviefile_path}"

# ================================================
# Funções Auxiliares
# ================================================

# rotate_log_if_needed: Limpa o arquivo de log se >= 1MB
# Parâmetros: nenhum
# Retorno: nenhum
rotate_log_if_needed() {
  if [[ "$LOG_TO_FILE" == true && -f "$LOG_FILE" ]]; then
    local log_size
    if [[ "$(uname)" == "Linux" ]]; then
      log_size=$(stat -c %s "$LOG_FILE" 2>/dev/null)
    else
      log_size=$(stat -f %z "$LOG_FILE" 2>/dev/null)
    fi

    if [[ -n "$log_size" && "$log_size" -ge 1048576 ]]; then
      >"$LOG_FILE"
    fi
  fi
}

# log_universal: Exibe mensagem com timestamp no console ou arquivo de log
# Parâmetros: $1 = mensagem
# Retorno: nenhum
log_universal() {
  local msg="$1"
  local ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
  if [[ "$LOG_TO_FILE" == true ]]; then
    echo "$ts $msg" >>"$LOG_FILE"
  else
    echo "$ts $msg"
  fi
}

# handle_interrupt: Trata interrupção (Ctrl+C), remove arquivo parcial e encerra
# Parâmetros: nenhum
# Retorno: encerra o script com exit 1
handle_interrupt() {
  log_universal ""
  log_universal "⏹ Interrupção detectada. Abortando processo..."
  INTERRUPTED=true

  if [[ -n "$CURRENT_NEW_FILE" && -f "$CURRENT_NEW_FILE" ]]; then
    log_universal "🧹 Removendo arquivo parcial: $(basename "$CURRENT_NEW_FILE")"
    rm -f "$CURRENT_NEW_FILE"
  fi

  exit 1
}

# check_dependencies: Verifica se mkvmerge e jq estão disponíveis
# Parâmetros: nenhum
# Retorno: encerra o script com exit 1 se faltar dependência
check_dependencies() {
  local missing=()

  if ! command -v mkvmerge &>/dev/null; then
    missing+=("mkvmerge (MKVToolNix)")
  fi

  if ! command -v jq &>/dev/null; then
    missing+=("jq")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_universal "Erro: As seguintes dependências estão faltando:"
    for dep in "${missing[@]}"; do
      log_universal "  - $dep"
    done
    exit 1
  fi
}

# check_media_file: Verifica se o arquivo existe e é um formato suportado (MKV/MP4)
# Parâmetros: $1 = arquivo
# Retorno: 0=ok, 1=arquivo não encontrado, 2=formato não suportado
check_media_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    log_universal "Erro: Arquivo '$file' não encontrado"
    return 1
  fi

  # Permitir .mkv e .mp4
  if [[ "$file" != *.mkv && "$file" != *.mp4 ]]; then
    log_universal "Erro: '$file' não é um formato suportado (apenas MKV ou MP4)"
    return 2
  fi

  if ! mkvmerge -i "$file" &>/dev/null; then
    log_universal "Erro: '$file' não é um arquivo multimídia válido para o mkvmerge"
    return 2
  fi

  return 0
}

# get_subtitles_to_remove: Retorna legendas a remover conforme KEEP_LANGS
# Parâmetros: $1 = arquivo
# Retorno: lista de legendas a remover
get_subtitles_to_remove() {
  local file="$1"
  local langs_3c=()
  local langs_ietf=()

  IFS=',' read -ra langs <<<"$KEEP_LANGS"

  for lang in "${langs[@]}"; do
    lang_lower=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
    if [[ ${#lang_lower} -eq 3 ]]; then
      langs_3c+=("$lang_lower")
    elif [[ ${#lang_lower} -ge 2 ]]; then
      langs_ietf+=("$lang_lower")
    fi
  done

  local jq_filter=".tracks[] | select(.type == \"subtitles\")"
  local conditions=()

  if [[ ${#langs_3c[@]} -gt 0 ]]; then
    local lang_condition=""
    for lang in "${langs_3c[@]}"; do
      if [[ -z "$lang_condition" ]]; then
        lang_condition="(.properties.language // \"\" | ascii_downcase) != \"$lang\""
      else
        lang_condition="$lang_condition and (.properties.language // \"\" | ascii_downcase) != \"$lang\""
      fi
    done
    conditions+=("($lang_condition)")
  fi

  if [[ ${#langs_ietf[@]} -gt 0 ]]; then
    local ietf_condition=""
    for lang in "${langs_ietf[@]}"; do
      if [[ -z "$ietf_condition" ]]; then
        ietf_condition="(.properties.language_ietf // \"\" | ascii_downcase) != \"$lang\""
      else
        ietf_condition="$ietf_condition and (.properties.language_ietf // \"\" | ascii_downcase) != \"$lang\""
      fi
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

# get_track_ids_by_type: Retorna IDs de tracks do tipo informado
# Parâmetros: $1 = arquivo, $2 = tipo, $3 = filtro
# Retorno: lista de IDs
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

# has_subtitles_to_keep: Verifica se há legendas para manter
# Parâmetros: $1 = arquivo
# Retorno: 0=sim, 1=não
has_subtitles_to_keep() {
  local file="$1"
  local subtitles_to_keep
  subtitles_to_keep=$(get_track_ids_by_type "$file" "subtitles" "keep")
  [[ -n "$subtitles_to_keep" ]]
}

# build_mkvmerge_command: Monta comando mkvmerge para processar arquivo
# Parâmetros: $1 = arquivo, $2 = saída
# Retorno: comando mkvmerge
build_mkvmerge_command() {
  local file="$1"
  local output_file="$2"
  local video_tracks=$(get_track_ids_by_type "$file" "video" "all" | tr '\n' ',' | sed 's/,$//')
  local audio_tracks=$(get_track_ids_by_type "$file" "audio" "all" | tr '\n' ',' | sed 's/,$//')
  local subtitle_tracks=$(get_track_ids_by_type "$file" "subtitles" "keep" | tr '\n' ',' | sed 's/,$//')
  local command="mkvmerge -o \"$output_file\""

  if [[ -n "$video_tracks" ]]; then
    command="$command -d $video_tracks"
  else
    command="$command -D"
  fi

  if [[ -n "$audio_tracks" ]]; then
    command="$command -a $audio_tracks"
  else
    command="$command -A"
  fi

  if [[ -n "$subtitle_tracks" ]]; then
    command="$command -s $subtitle_tracks"
  else
    command="$command -S"
  fi

  command="$command \"$file\""
  echo "$command"
}

# execute_mkvmerge: Executa comando mkvmerge gerado
# Parâmetros: $1 = arquivo, $2 = saída
# Retorno: exit code do mkvmerge
execute_mkvmerge() {
  local file="$1"
  local output_file="$2"
  local mkvmerge_cmd=$(build_mkvmerge_command "$file" "$output_file")

  if [[ "$DRY_RUN" == true ]]; then
    log_universal ""
    log_universal "MODO SIMULAÇÃO - Nenhum arquivo será modificado"
    log_universal "Comando que seria executado: $mkvmerge_cmd"
    return 0
  fi

  log_universal ""
  log_universal "Executando: $mkvmerge_cmd"

  # Cria pasta de saída se não existir
  mkdir -p "$(dirname "$output_file")"

  # Executa mkvmerge com prioridade mínima e loga direto no console
  eval "nice -n 19 $mkvmerge_cmd"
  return $?
}

# validate_file: Valida arquivo de entrada e parâmetros
# Parâmetros: $1 = arquivo de entrada, $2 = saída
# Retorno: 0=ok, 1=sem KEEP_LANGS, 2=arquivo não encontrado, 5=não é MKV
validate_file() {
  local input_file="$1"
  local output_file="$2"
  if [[ ! -f "$input_file" ]]; then
    log_universal "❌ Erro: Arquivo de entrada não encontrado"
    return 2
  fi
  local mkv_check=$(check_media_file "$input_file")
  local mkv_result=$?
  if [[ $mkv_result -ne 0 ]]; then
    CURRENT_NEW_FILE=""
    return 5
  fi
  if [[ -z "$KEEP_LANGS" ]]; then
    log_universal "ℹ️  Nenhuma linguagem definida para manter. Não será processado."
    CURRENT_NEW_FILE=""
    return 1
  fi
  return 0
}

# log_kept_tracks: Loga tracks de legenda que serão mantidas
# Parâmetros: $1 = arquivo
# Retorno: nenhum
log_kept_tracks() {
  local input_file="$1"
  local kept_tracks_ids=$(get_track_ids_by_type "$input_file" "subtitles" "keep")
  if [[ -n "$kept_tracks_ids" ]]; then
    log_universal ""
    log_universal "Faixas de legenda mantidas:"
    local info_json=$(mkvmerge -J "$input_file" 2>/dev/null)
    for tid in $kept_tracks_ids; do
      local lang=$(echo "$info_json" | jq -r ".tracks[] | select(.id==$tid and .type==\"subtitles\") | .properties.language // \"\"")
      local name=$(echo "$info_json" | jq -r ".tracks[] | select(.id==$tid and .type==\"subtitles\") | .properties.track_name // \"\"")
      if [[ -n "$lang" && "$lang" != "null" ]]; then
        if [[ -n "$name" && "$name" != "null" && "$name" != "unknown" ]]; then
          log_universal "  - Faixa $tid: $lang ($name)"
        else
          log_universal "  - Faixa $tid: $lang"
        fi
      else
        log_universal "  - Faixa $tid: (sem linguagem especificada)"
      fi
    done
  else
    log_universal "Nenhuma faixa de legenda será mantida."
  fi
}

# log_removed_tracks: Loga faixas de legenda que serão removidas
# Parâmetros: $1 = arquivo
# Retorno: nenhum
log_removed_tracks() {
  local input_file="$1"
  local subs_to_remove=$(get_subtitles_to_remove "$input_file")

  log_universal ""
  log_universal "Faixas de legenda a remover:"

  if [[ -n "$subs_to_remove" ]]; then
    while IFS=: read -r track_id language track_name; do
      if [[ -n "$track_id" && "$track_id" =~ ^[0-9]+$ ]]; then
        if [[ -n "$track_name" && "$track_name" != "unknown" && "$track_name" != "" ]]; then
          log_universal "  - Faixa $track_id: $language ($track_name)"
        else
          log_universal "  - Faixa $track_id: $language"
        fi
      fi
    done <<<"$subs_to_remove"
  fi
}

# show_help: Exibe ajuda de uso do script
# Parâmetros: nenhum
# Retorno: nenhum
show_help() {
  cat <<EOF
Script de importação para remover legendas não-desejadas de arquivos MKV ou MP4

Uso como script de importação *Arr:
  Configure como Custom Script com os triggers:
    - On Import
    - On Upgrade

  O Sonar passará as variáveis de ambiente:
    sonarr_eventtype: Tipo de evento (Download, Upgrade, Test, etc.)
    sonarr_episodefile_sourcepath: Caminho do arquivo baixado (pasta temporária)
    sonarr_episodefile_path: Caminho de destino final

  O Radarr passará as variáveis de ambiente:
    radarr_eventtype: Tipo de evento (Download, Upgrade, Test, etc.)
    radarr_moviefile_sourcepath: Caminho do arquivo baixado (pasta temporária)
    radarr_moviefile_path: Caminho de destino final

Uso via linha de comando (para testes):
  $0 -in <arquivo_entrada> -out <arquivo_saida> [opções]

Opções:
  -in ARQUIVO      Arquivo de entrada (MKV ou MP4)
  -out ARQUIVO     Arquivo de saída (destino)
  -keep LANG1,LANG2 Linguagens de legenda a manter (padrão: pt-br)
  -d, --dry-run    Simular sem modificar arquivos
  -h, --help       Mostrar esta ajuda

Exemplos:
  # Testar com arquivo local
  $0 -in /tmp/video.mkv -out /media/series/video.mkv

  # Testar em modo simulação
  $0 -in /tmp/video.mkv -out /media/series/video.mkv --dry-run

  # Manter português e inglês
  $0 -in /tmp/video.mkv -out /media/series/video.mkv -keep pt-br,eng
EOF
}

# copy_input_to_output: Copia o arquivo de entrada para o arquivo de saída, criando o diretório se necessário
# Parâmetros: $1 = arquivo de entrada, $2 = arquivo de saída
# Retorno: 0=sucesso, 4=erro ao copiar

# validate_output_file: Verifica se o arquivo de saída existe e não está vazio
# Parâmetros: $1 = arquivo de saída
# Retorno: 0=sucesso, 3=erro (arquivo vazio ou inexistente)
validate_output_file() {
  local output_file="$1"
  if [[ -f "$output_file" && -s "$output_file" ]]; then
    log_universal "OK: Processamento concluído!"
    CURRENT_NEW_FILE=""
    return 0
  else
    log_universal "Erro: Arquivo processado está vazio"
    if [[ -f "$output_file" ]]; then
      rm -f "$output_file"
    fi
    CURRENT_NEW_FILE=""
    return 3
  fi
}

# process_file: Processa um arquivo multimídia
# Parâmetros: $1 = arquivo de entrada, $2 = arquivo de saída
# Retorna: 0=sucesso, 1=erro, 2=formato incompatível, 3=sem legendas para manter
process_file() {
  local input_file="$1"
  local output_file="$2"
  local final_output="${output_file%.*}.mkv"
  local temp_output="${final_output}.tmp.mkv"
  local is_inplace=false

  # Se o input não existe (Radarr já moveu), mas o destino existe, tratamos como in-place
  if [[ ! -f "$input_file" && -f "$output_file" ]]; then
    input_file="$output_file"
  fi

  # Se fonte e destino forem o mesmo arquivo, usamos saída temporária
  if [[ "$input_file" == "$final_output" ]]; then
    is_inplace=true
    output_file="$temp_output"
  else
    output_file="$final_output"
  fi

  CURRENT_NEW_FILE="$output_file"

  log_universal ""
  log_universal "=== Processando arquivo ==="
  log_universal "Linguagens a manter: $KEEP_LANGS"

  validate_file "$input_file" "$output_file"
  local valid_result=$?
  if [[ $valid_result -ne 0 ]]; then
    return $valid_result
  fi

  log_kept_tracks "$input_file"
  log_removed_tracks "$input_file"

  execute_mkvmerge "$input_file" "$output_file"
  local mkvmerge_result=$?
  if [[ $mkvmerge_result -ne 0 ]]; then
    log_universal "KO: mkvmerge falhou com código ($mkvmerge_result). Abortando."
    [[ -f "$temp_output" ]] && rm -f "$temp_output"
    exit 6
  fi

  if [[ -f "$output_file" && -s "$output_file" ]]; then
    if [[ "$is_inplace" == true ]]; then
      log_universal "OK: Transcode in-place concluído. Substituindo original..."
      mv -f "$output_file" "$final_output"
    fi
    log_universal "OK: Arquivo transcodado criado com sucesso"
    validate_output_file "$final_output"
    return $?
  else
    log_universal "KO: Erro ao criar arquivo transcodado"
    [[ -f "$temp_output" ]] && rm -f "$temp_output"
    CURRENT_NEW_FILE=""
    return 3
  fi
}

# ================================================
# MODO CLI (Linha de Comando)
# ================================================

# cli_mode: Modo de execução via linha de comando
# Parâmetros: argumentos da linha de comando
# Retorno: exit 0=sucesso, exit 1=erro
cli_mode() {
  log_universal "=== Modo CLI ==="

  # Processar argumentos
  while [[ $# -gt 0 ]]; do
    case $1 in
    -in)
      SOURCE_PATH="$2"
      shift 2
      ;;
    -out)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    -keep)
      KEEP_LANGS="$2"
      shift 2
      ;;
    -d | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    -*)
      log_universal "Erro: Opção desconhecida $1"
      show_help
      exit 1
      ;;
    *)
      log_universal "Erro: Argumento inválido $1"
      show_help
      exit 1
      ;;
    esac
  done

  # Validar parâmetros
  if [[ -z "$SOURCE_PATH" ]]; then
    log_universal "Erro: Parâmetro -in não especificado"
    show_help
    exit 1
  fi

  if [[ -z "$OUTPUT_PATH" ]]; then
    log_universal "Erro: Parâmetro -out não especificado"
    show_help
    exit 1
  fi

  if [[ ! -f "$SOURCE_PATH" ]]; then
    log_universal "Erro: Arquivo de entrada não encontrado: $SOURCE_PATH"
    exit 1
  fi

  # Verificar dependências
  check_dependencies

  # Log das variáveis (útil para debug)
  log_universal "Arquivo fonte: $SOURCE_PATH"
  log_universal "Destino final: $OUTPUT_PATH"

  # Processar arquivo
  process_file "$SOURCE_PATH" "$OUTPUT_PATH"
  local result=$?
  if [[ $result -eq 0 ]]; then
    exit 0
  else
    exit 1
  fi
}

# ================================================
# MODO ARR (Variáveis de Ambiente)
# ================================================

# arr_mode: Modo de execução via *Arr
# Parâmetros: variáveis de ambiente do *Arr
# Retorno: exit 0=sucesso, exit 3=erro
arr_mode() {
  LOG_TO_FILE=true
  rotate_log_if_needed
  log_universal "=== Modo *Arr (Evento: ${EVENT_TYPE}) ==="

  # Verificar se é evento suportado
  if [[ "$EVENT_TYPE" != "Download" && "$EVENT_TYPE" != "Upgrade" && "$EVENT_TYPE" != "Test" ]]; then
    log_universal "Evento não suportado: $EVENT_TYPE"
    log_universal "Eventos suportados: Download, Upgrade, Test"
    exit 0
  fi

  # Sair sem erro ao receber o evento de teste
  if [[ "$EVENT_TYPE" == "Test" ]]; then
    log_universal "Evento de teste recebido. Encerrando."
    exit 0
  fi

  # Verificar variáveis obrigatórias do servidor
  if [[ -z "$SOURCE_PATH" ]]; then
    log_universal "Erro: Arquivo de origem não definido"
    exit 1
  fi

  # Se não for MKV ou MP4, apenas copia para o destino (trigger para ignorar transcodificação se desejado)
  if [[ "$SOURCE_PATH" != *.mkv && "$SOURCE_PATH" != *.mp4 ]]; then
    exit 5
  fi

  if [[ -z "$OUTPUT_PATH" ]]; then
    log_universal "Erro: Arquivo de destino não definido"
    exit 2
  fi

  # Log das variáveis (útil para debug)
  log_universal "Evento: $EVENT_TYPE"
  log_universal "Arquivo fonte: $SOURCE_PATH"
  log_universal "Destino final: $OUTPUT_PATH"

  # Verificar dependências
  log_universal ""
  log_universal "Verificando dependências..."
  check_dependencies

  log_universal "Iniciando processamento do arquivo..."
  process_file "$SOURCE_PATH" "$OUTPUT_PATH"

  local result=$?
  if [[ $result -eq 0 ]]; then
    exit 0
  else
    exit 3
  fi
}

# ================================================
# PONTO DE ENTRADA PRINCIPAL
# ================================================

trap handle_interrupt SIGINT

if [[ -n "$EVENT_TYPE" ]]; then
  arr_mode
else
  cli_mode "$@"
fi
