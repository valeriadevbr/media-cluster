#!/bin/bash

# Script para extrair legendas de arquivos MKV
# Uso: ./extrair_legendas.sh [arquivo_ou_pasta] [idiomas]

# Configurações padrão
DEFAULT_LANGUAGES="por"
TARGET="${1:-.}"  # Usa o primeiro argumento ou diretório atual
LANGUAGES="${2:-$DEFAULT_LANGUAGES}"

# Variável para controle de interrupção
INTERRUPTED=false
CURRENT_OUTPUT_FILE=""
PARTIAL_FILES=()

# Função para tratar interrupção via Ctrl+C
handle_interrupt() {
    echo ""
    echo "⏹️  Interrupção detectada. Abortando processo..."
    INTERRUPTED=true

    # Remover todos os arquivos parciais
    if [[ ${#PARTIAL_FILES[@]} -gt 0 ]]; then
        echo "🧹 Removendo arquivos parciais..."
        for partial_file in "${PARTIAL_FILES[@]}"; do
            if [[ -f "$partial_file" ]]; then
                echo "  Removendo: $(basename "$partial_file")"
                rm -f "$partial_file"
            fi
        done
    fi

    exit 1
}

# Registrar o handler para SIGINT (Ctrl+C)
trap handle_interrupt SIGINT

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 [arquivo_ou_pasta] [idiomas]"
    echo ""
    echo "Exemplos:"
    echo "  $0                                  # Extrai do diretório atual, idioma padrão (por)"
    echo "  $0 arquivo.mkv                      # Extrai de um arquivo específico"
    echo "  $0 /caminho/para/videos            # Extrai do caminho especificado"
    echo "  $0 . por eng                       # Extrai do diretório atual, português e inglês"
    echo "  $0 video.mkv por eng               # Extrai do arquivo, português e inglês"
    echo ""
    echo "Idiomas disponíveis: por, eng, spa, fre, ita, etc."
}

# Função para verificar dependências
check_dependencies() {
    local missing=()

    if ! command -v mkvmerge &> /dev/null; then
        missing+=("mkvmerge (MKVToolNix)")
    fi

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Erro: As seguintes dependências estão faltando:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# Função para formatar idiomas para jq
format_languages_for_jq() {
    local langs="$1"
    # Converte "por eng spa" para '"por","eng","spa"'
    echo "$langs" | sed 's/ /","/g' | sed 's/^/"/' | sed 's/$/"/'
}

# Função para criar nome de arquivo seguro
create_safe_filename() {
    local base_name="$1"
    local code="$2"
    local track_name="$3"

    # Se track_name existe e não é "unknown", adiciona ao nome
    if [[ "$track_name" != "unknown" && -n "$track_name" ]]; then
        # Limpar track_name: substituir espaços por underscores e remover caracteres especiais
        local safe_track_name=$(echo "$track_name" | tr ' ' '_' | tr -cd '[:alnum:]._-')
        echo "${base_name}.${code}.${safe_track_name}.srt"
    else
        echo "${base_name}.${code}.srt"
    fi
}

# Função para verificar se arquivo já existe e é válido
should_skip_extraction() {
    local output_file="$1"

    # Se o arquivo não existe, não pular
    if [[ ! -f "$output_file" ]]; then
        return 1  # false - não pular
    fi

    # Se o arquivo existe mas está vazio (0 bytes), não pular (permite reextrair)
    if [[ ! -s "$output_file" ]]; then
        echo "  ⚠️  Arquivo existe mas está vazio. Reextraindo: $(basename "$output_file")"
        return 1  # false - não pular
    fi

    # Verificar se é um arquivo de legenda válido (pelo menos contém timestamps)
    if head -n 2 "$output_file" | grep -q -E '[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}.*[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}'; then
        echo "  ⏭️  Pulando: Arquivo já existe e é válido: $(basename "$output_file")"
        return 0  # true - pular
    else
        echo "  ⚠️  Arquivo existe mas parece inválido. Reextraindo: $(basename "$output_file")"
        return 1  # false - não pular
    fi
}

# Função para adicionar arquivo à lista de parciais
add_partial_file() {
    local file="$1"
    PARTIAL_FILES+=("$file")
}

# Função para remover arquivo da lista de parciais
remove_partial_file() {
    local file="$1"
    local new_array=()
    for item in "${PARTIAL_FILES[@]}"; do
        if [[ "$item" != "$file" ]]; then
            new_array+=("$item")
        fi
    done
    PARTIAL_FILES=("${new_array[@]}")
}

# Função principal para processar um arquivo
process_file() {
    local file="$1"
    local file_dir=$(dirname "$file")
    local base_name="${file%.mkv}"
    local base_name_only=$(basename "$base_name")

    echo "Processando: $file"

    # Verificar se foi interrompido
    if [[ $INTERRUPTED == true ]]; then
        return 1
    fi

    # Contador de legendas extraídas
    local extracted_count=0
    local skipped_count=0

    # Formatar idiomas para a consulta jq
    local jq_languages
    jq_languages=$(format_languages_for_jq "$LANGUAGES")

    # Extrair informações das legendas primeiro
    local tracks_info
    tracks_info=$(mkvmerge -J "$file" | jq -r "
      .tracks[] |
      select(.type == \"subtitles\" and (.properties.language | inside($jq_languages))) |
      \"\\(.id):\\(.properties.language_ietf // .properties.language // \"unknown\"):\\(.properties.track_name // \"unknown\")\"
    ")

    # Processar cada track
    while IFS=: read -r track_id code track_name; do
        # Verificar se foi interrompido a cada iteração
        if [[ $INTERRUPTED == true ]]; then
            break
        fi

        # Criar nome de arquivo no formato especificado
        local output_filename
        output_filename=$(create_safe_filename "$base_name_only" "$code" "$track_name")

        # Caminho completo para o arquivo de legenda (mesma pasta do MKV)
        local output_file="${file_dir}/${output_filename}"

        # Verificar se deve pular a extração
        if should_skip_extraction "$output_file"; then
            ((skipped_count++))
            continue
        fi

        # Se o arquivo existe mas está vazio, remover para reextrair
        if [[ -f "$output_file" && ! -s "$output_file" ]]; then
            rm -f "$output_file"
        fi

        echo "  📥 Extraindo: $code (track $track_id) - '$track_name' -> $(basename "$output_file")"

        # Adicionar à lista de arquivos parciais antes da extração
        add_partial_file "$output_file"

        # Executar a extração
        if mkvextract tracks "$file" "$track_id:$output_file" 2>/dev/null; then
            ((extracted_count++))
            echo "  ✅ Concluído: $(basename "$output_file")"
            # Remover da lista de parciais após sucesso
            remove_partial_file "$output_file"
        else
            echo "  ❌ Erro ao extrair track $track_id"
            # Remover arquivo parcial em caso de erro
            if [[ -f "$output_file" ]]; then
                rm -f "$output_file"
                remove_partial_file "$output_file"
            fi
        fi

    done <<< "$tracks_info"

    # Verificar se foi interrompido
    if [[ $INTERRUPTED == true ]]; then
        echo "  ❌ Processo interrompido para este arquivo"
        return 1
    fi

    if [[ $extracted_count -eq 0 && $skipped_count -eq 0 ]]; then
        echo "  ℹ️  Nenhuma legenda encontrada para os idiomas: $LANGUAGES"
    else
        echo "  📊 Resumo: $extracted_count extraída(s), $skipped_count pulada(s)"
    fi
}

# Verificar se help foi solicitado
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Verificar dependências
check_dependencies

# Determinar se o target é arquivo ou diretório
if [[ -f "$TARGET" ]]; then
    # É um arquivo
    if [[ "$TARGET" == *.mkv ]]; then
        echo "Processando arquivo: $TARGET"
        echo "Idiomas: $LANGUAGES"
        echo "---"
        process_file "$TARGET"
        if [[ $INTERRUPTED == true ]]; then
            echo "❌ Processo abortado pelo usuário"
            exit 1
        else
            echo "✅ Processamento concluído!"
        fi
    else
        echo "Erro: '$TARGET' não é um arquivo MKV"
        exit 1
    fi
elif [[ -d "$TARGET" ]]; then
    # É um diretório
    echo "Buscando arquivos MKV em: $TARGET"
    echo "Idiomas: $LANGUAGES"
    echo "---"

    # Buscar arquivos MKV
    mkv_files=()
    for file in "$TARGET"/*.mkv; do
        [[ -f "$file" ]] && mkv_files+=("$file")
    done

    # Se não encontrou com glob, tenta com find (para casos onde o glob pode falhar)
    if [[ ${#mkv_files[@]} -eq 0 ]]; then
        while IFS= read -r -d $'\0' file; do
            mkv_files+=("$file")
        done < <(find "$TARGET" -maxdepth 1 -name "*.mkv" -type f -print0 2>/dev/null)
    fi

    if [[ ${#mkv_files[@]} -eq 0 ]]; then
        echo "Nenhum arquivo MKV encontrado em '$TARGET'"
        exit 1
    fi

    # Ordenar arquivos alfabeticamente
    IFS=$'\n' mkv_files=($(sort <<<"${mkv_files[*]}"))
    unset IFS

    echo "Encontrados ${#mkv_files[@]} arquivo(s) MKV:"
    for file in "${mkv_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo "---"

    # Processar cada arquivo
    total_files=${#mkv_files[@]}
    current=0

    for file in "${mkv_files[@]}"; do
        # Verificar se foi interrompido antes de processar próximo arquivo
        if [[ $INTERRUPTED == true ]]; then
            echo "❌ Processo abortado pelo usuário"
            exit 1
        fi

        ((current++))
        echo "[$current/$total_files] $(basename "$file")"
        process_file "$file"

        # Verificar se foi interrompido após processar arquivo
        if [[ $INTERRUPTED == true ]]; then
            echo "❌ Processo abortado pelo usuário"
            exit 1
        fi

        echo
    done

    echo "✅ Processamento concluído!"
else
    echo "Erro: '$TARGET' não encontrado (não é arquivo nem diretório)"
    exit 1
fi
