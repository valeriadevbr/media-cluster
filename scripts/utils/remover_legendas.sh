#!/bin/bash

# Script para remover faixas de legenda não-desejadas de arquivos MKV
# Uso: ./remover_legendas.sh -in [arquivo_ou_pasta] -out [pasta_destino] [opções]

# Variáveis globais
INPUT=""
OUTPUT=""
DRY_RUN=false
VERBOSE=false
INTERRUPTED=false
CURRENT_NEW_FILE=""
KEEP_LANGS="pt-br"  # Linguagens padrão para manter (português)

# Função para tratar interrupção via Ctrl+C
handle_interrupt() {
    echo ""
    echo "⏹️  Interrupção detectada. Abortando processo..."
    INTERRUPTED=true

    # Remover arquivo parcial se existir
    if [[ -n "$CURRENT_NEW_FILE" && -f "$CURRENT_NEW_FILE" ]]; then
        echo "🧹 Removendo arquivo parcial: $(basename "$CURRENT_NEW_FILE")"
        rm -f "$CURRENT_NEW_FILE"
    fi

    exit 1
}

# Registrar o handler para SIGINT (Ctrl+C)
trap handle_interrupt SIGINT

# Função para mostrar uso
show_usage() {
    echo "Uso: $0 -in [arquivo_ou_pasta] -out [pasta_destino] [opções]"
    echo ""
    echo "Opções:"
    echo "  -d, --dry-run      Simular sem modificar arquivos"
    echo "  -v, --verbose      Mostrar informações detalhadas"
    echo "  -h, --help         Mostrar esta ajuda"
    echo "  -keep LANG1,LANG2  Linguagens de legenda a manter (padrão: por)"
    echo "                     Exemplo: -keep por,eng,spa"
    echo ""
    echo "Exemplos:"
    echo "  $0 -in video.mkv -out ./processados              # Processa arquivo específico"
    echo "  $0 -in /caminho/para/videos -out ./resultados    # Processa diretório específico"
    echo "  $0 -in video.mkv -out ./saida --dry-run          # Simular processamento"
    echo "  $0 -in /caminho/para/videos -out ./saida -keep por,eng  # Manter português e inglês"
}

# Função para validar e processar linguagens
validate_and_process_languages() {
    local languages="$1"

    # Converter para minúsculas e remover espaços
    languages=$(echo "$languages" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

    # Validar formato (apenas letras, vírgulas, e hífen são permitidos)
    if [[ ! "$languages" =~ ^[a-z,-]+$ ]]; then
        echo "Erro: Formato de linguagens inválido: '$languages'"
        echo "Use códigos de 3 caracteres separados por vírgulas (ex: por,eng,spa)"
        exit 1
    fi

    # Validar que cada linguagem tem pelo menos 2 caracteres
    IFS=',' read -ra lang_array <<< "$languages"
    for lang in "${lang_array[@]}"; do
        if [[ ${#lang} -lt 2 ]]; then
            echo "Erro: Linguagem '$lang' deve ter pelo menos 2 caracteres"
            exit 1
        fi
    done

    echo "$languages"
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

    if ! command -v dd &> /dev/null; then
        missing+=("dd")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Erro: As seguintes dependências estão faltando:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# Função para resolver caminho absoluto
get_absolute_path() {
    local path="$1"

    # Se o caminho é relativo, converte para absoluto
    if [[ "$path" != /* ]]; then
        path="$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi

    # Remove trailing slash se existir
    echo "${path%/}"
}

# Função para validar parâmetros de entrada e saída
validate_input_output() {
    local input="$1"
    local output="$2"

    # Verificar se os parâmetros foram fornecidos
    if [[ -z "$input" ]]; then
        echo "Erro: Parâmetro -in não especificado"
        show_usage
        exit 1
    fi

    if [[ -z "$output" ]]; then
        echo "Erro: Parâmetro -out não especificado"
        show_usage
        exit 1
    fi

    # Resolver caminhos absolutos
    INPUT=$(get_absolute_path "$input")
    OUTPUT=$(get_absolute_path "$output")

    # Verificar se entrada existe
    if [[ ! -e "$INPUT" ]]; then
        echo "Erro: Entrada '$INPUT' não encontrada"
        exit 1
    fi

    # Verificar se saída é um diretório
    if [[ -e "$OUTPUT" && ! -d "$OUTPUT" ]]; then
        echo "Erro: Saída '$OUTPUT' não é um diretório"
        exit 1
    fi

    # Criar diretório de saída se não existir
    if [[ ! -d "$OUTPUT" ]]; then
        echo "Criando diretório de saída: $OUTPUT"
        mkdir -p "$OUTPUT"
    fi

    # Verificar se entrada e saída são diferentes
    if [[ "$INPUT" == "$OUTPUT" ]]; then
        echo "Erro: Diretório de entrada e saída não podem ser o mesmo"
        echo "  Entrada: $INPUT"
        echo "  Saída:   $OUTPUT"
        exit 1
    fi

    # Verificar se entrada está dentro da saída
    if [[ "$INPUT" == "$OUTPUT"/* ]]; then
        echo "Erro: Diretório de entrada não pode estar dentro do diretório de saída"
        echo "  Entrada: $INPUT"
        echo "  Saída:   $OUTPUT"
        exit 1
    fi

    # Verificar se saída está dentro da entrada (quando entrada é diretório)
    if [[ -d "$INPUT" && "$OUTPUT" == "$INPUT"/* ]]; then
        echo "Erro: Diretório de saída não pode estar dentro do diretório de entrada"
        echo "  Entrada: $INPUT"
        echo "  Saída:   $OUTPUT"
        exit 1
    fi
}

# Função para verificar se é arquivo MKV válido
check_mkv_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Erro: Arquivo '$file' não encontrado"
        return 1
    fi

    if [[ "$file" != *.mkv ]]; then
        echo "Erro: '$file' não é um arquivo MKV"
        return 1
    fi

    # Verificar se o arquivo é um MKV válido
    if ! mkvmerge -i "$file" &>/dev/null; then
        echo "Erro: '$file' não é um arquivo MKV válido"
        return 1
    fi

    return 0
}

# Função para verificar se arquivo de destino já existe
check_destination_exists() {
    local input_file="$1"
    local output_dir="$2"
    local base_name=$(basename "$input_file")
    local output_file="$output_dir/$base_name"

    if [[ -f "$output_file" ]]; then
        return 0  # Arquivo de destino existe
    else
        return 1  # Arquivo de destino não existe
    fi
}

# Função para copiar arquivo com progresso usando dd
copy_with_progress() {
    local source="$1"
    local destination="$2"

    echo "  📤 Copiando arquivo com progresso..."

    # Usar dd com status=progress para mostrar progresso
    if dd if="$source" of="$destination" bs=4M status=progress; then
        echo "  ✅ Cópia concluída com sucesso"
        return 0
    else
        echo "  ❌ Erro durante a cópia"
        # Remover arquivo parcial em caso de erro
        if [[ -f "$destination" ]]; then
            rm -f "$destination"
        fi
        return 1
    fi
}

# Função para obter tracks de legenda a remover (não estão na lista KEEP_LANGS)
get_subtitles_to_remove() {
    local file="$1"

    # Separar linguagens para language (3 caracteres) e language_ietf (>=2, mas !=3)
    local langs_3c=()
    local langs_ietf=()
    IFS=',' read -ra langs <<< "$KEEP_LANGS"
    for lang in "${langs[@]}"; do
        if [[ ${#lang} -eq 3 ]]; then
            langs_3c+=("$lang")
        elif [[ ${#lang} -ge 2 ]]; then
            langs_ietf+=("$lang")
        fi
    done

    # Construir filtro JQ
    local jq_filter=".tracks[] | select(.type == \"subtitles\")"

    # Adicionar condições de exclusão (NÃO manter)
    local conditions=()

    if [[ ${#langs_3c[@]} -gt 0 ]]; then
        local lang_condition=""
        for lang in "${langs_3c[@]}"; do
            if [[ -z "$lang_condition" ]]; then
                lang_condition=".properties.language != \"$lang\""
            else
                lang_condition="$lang_condition and .properties.language != \"$lang\""
            fi
        done
        conditions+=("($lang_condition)")
    fi

    if [[ ${#langs_ietf[@]} -gt 0 ]]; then
        local ietf_condition=""
        for lang in "${langs_ietf[@]}"; do
            if [[ -z "$ietf_condition" ]]; then
                ietf_condition=".properties.language_ietf != \"$lang\""
            else
                ietf_condition="$ietf_condition and .properties.language_ietf != \"$lang\""
            fi
        done
        conditions+=("($ietf_condition)")
    fi

    # Combinar condições - para remover, a track NÃO deve ter NENHUMA das linguagens
    if [[ ${#conditions[@]} -eq 2 ]]; then
        jq_filter="$jq_filter | select(${conditions[0]} and ${conditions[1]})"
    elif [[ ${#conditions[@]} -eq 1 ]]; then
        jq_filter="$jq_filter | select(${conditions[0]})"
    fi

    # Filtrar apenas tracks com linguagem conhecida e adicionar saída
    jq_filter="$jq_filter | select(.properties.language != null and .properties.language != \"unknown\")"
    jq_filter="$jq_filter | \"\\(.id):\\(.properties.language):\\(.properties.track_name // \"\")\""

    mkvmerge -J "$file" | jq -r "$jq_filter"
}

# Função para formatar a exibição das tracks
format_track_display() {
    local track_id="$1"
    local language="$2"
    local track_name="$3"

    if [[ -n "$track_name" && "$track_name" != "unknown" ]]; then
        echo "    - Track $track_id: $language ($track_name)"
    else
        echo "    - Track $track_id: $language"
    fi
}

# Função para obter lista de track IDs por tipo
get_track_ids_by_type() {
    local file="$1"
    local track_type="$2"  # "video", "audio", "subtitles"
    local language_filter="$3"  # "all" ou "keep"

    if [[ "$language_filter" == "keep" ]]; then
        # Separar linguagens para language (3 caracteres) e language_ietf (>=2, mas !=3)
        local langs_3c=()
        local langs_ietf=()
        IFS=',' read -ra keep_array <<< "$KEEP_LANGS"
        for lang in "${keep_array[@]}"; do
            if [[ ${#lang} -eq 3 ]]; then
                langs_3c+=("$lang")
            elif [[ ${#lang} -ge 2 ]]; then
                langs_ietf+=("$lang")
            fi
        done

        # Construir filtro JQ
        local jq_filter=".tracks[] | select(.type == \"$track_type\")"

        # Adicionar condições de inclusão (manter) com conversão para minúsculas
        local conditions=()

        if [[ ${#langs_3c[@]} -gt 0 ]]; then
            local lang_condition=""
            for lang in "${langs_3c[@]}"; do
                if [[ -z "$lang_condition" ]]; then
                    lang_condition="(.properties.language | ascii_downcase) == \"$lang\""
                else
                    lang_condition="$lang_condition or (.properties.language | ascii_downcase) == \"$lang\""
                fi
            done
            conditions+=("($lang_condition)")
        fi

        if [[ ${#langs_ietf[@]} -gt 0 ]]; then
            local ietf_condition=""
            for lang in "${langs_ietf[@]}"; do
                if [[ -z "$ietf_condition" ]]; then
                    ietf_condition="(.properties.language_ietf | ascii_downcase) == \"$lang\""
                else
                    ietf_condition="$ietf_condition or (.properties.language_ietf | ascii_downcase) == \"$lang\""
                fi
            done
            conditions+=("($ietf_condition)")
        fi

        # Combinar condições - para manter, a track deve ter PELO MENOS UMA das linguagens
        if [[ ${#conditions[@]} -eq 2 ]]; then
            jq_filter="$jq_filter | select(${conditions[0]} or ${conditions[1]})"
        elif [[ ${#conditions[@]} -eq 1 ]]; then
            jq_filter="$jq_filter | select(${conditions[0]})"
        else
            # Nenhuma linguagem para manter, retorna vazio
            jq_filter="$jq_filter | select(false)"
        fi

        # Filtrar apenas tracks com linguagem conhecida e adicionar saída
        jq_filter="$jq_filter | select(.properties.language != null and .properties.language != \"unknown\")"
        jq_filter="$jq_filter | \"\\(.id)\""

        mkvmerge -J "$file" | jq -r "$jq_filter"
    else
        # Para "all", retornar todas as tracks do tipo
        mkvmerge -J "$file" | jq -r --arg type "$track_type" '
            .tracks[] |
            select(.type == $type) |
            "\(.id)"
        '
    fi
}

# Função para verificar se existem legendas para manter
has_subtitles_to_keep() {
    local file="$1"

    local subtitles_to_keep
    subtitles_to_keep=$(get_track_ids_by_type "$file" "subtitles" "keep")

    [[ -n "$subtitles_to_keep" ]]
}

# Função para contar legendas a remover
count_subtitles_to_remove() {
    local file="$1"

    local subs_to_remove
    subs_to_remove=$(get_subtitles_to_remove "$file")

    local count=0
    while IFS=: read -r track_id language track_name; do
        # Verificar se a linha não está vazia e tem um track_id válido
        if [[ -n "$track_id" && "$track_id" =~ ^[0-9]+$ ]]; then
            ((count++))
        fi
    done <<< "$subs_to_remove"

    echo $count
}

# Função para construir comando mkvmerge
build_mkvmerge_command() {
    local file="$1"
    local output_file="$2"

    # Obter todas as tracks de vídeo (manter todas)
    local video_tracks
    video_tracks=$(get_track_ids_by_type "$file" "video" "all" | tr '\n' ',' | sed 's/,$//')

    # Obter todas as tracks de áudio (manter todas)
    local audio_tracks
    audio_tracks=$(get_track_ids_by_type "$file" "audio" "all" | tr '\n' ',' | sed 's/,$//')

    # Obter apenas legendas para manter
    local subtitle_tracks
    subtitle_tracks=$(get_track_ids_by_type "$file" "subtitles" "keep" | tr '\n' ',' | sed 's/,$//')

    # Construir o comando
    local command="mkvmerge -o \"$output_file\""

    # Adicionar seleção de tracks específicas
    if [[ -n "$video_tracks" ]]; then
        command="$command -d $video_tracks"
    else
        command="$command -D"  # Não copiar vídeo se não houver (improvável, mas seguro)
    fi

    if [[ -n "$audio_tracks" ]]; then
        command="$command -a $audio_tracks"
    else
        command="$command -A"  # Não copiar áudio se não houver
    fi

    if [[ -n "$subtitle_tracks" ]]; then
        command="$command -s $subtitle_tracks"
    else
        command="$command -S"  # Não copiar legendas se não houver para manter
    fi

    # Adicionar o arquivo de entrada
    command="$command \"$file\""

    echo "$command"
}

# Função para executar mkvmerge de forma segura
execute_mkvmerge() {
    local file="$1"
    local output_file="$2"

    # Construir comando
    local mkvmerge_cmd
    mkvmerge_cmd=$(build_mkvmerge_command "$file" "$output_file")

    # Executar o comando
    eval "$mkvmerge_cmd"
}

# Função para processar um único arquivo
# Retorna: 0=sucesso, 2=sem legendas para manter, 3=sem legendas para remover, 4=erro, 5=destino já existe
process_single_file() {
    local input_file="$1"
    local output_dir="$2"
    local base_name=$(basename "$input_file")
    local output_file="$output_dir/$base_name"

    # Atualizar variável global com arquivo atual sendo processado
    CURRENT_NEW_FILE="$output_file"

    echo "Processando: $input_file"
    echo "Destino: $output_file"
    echo "Linguagens a manter: $KEEP_LANGS"
    echo "---"

    # Verificar se foi interrompido
    if [[ $INTERRUPTED == true ]]; then
        return 4
    fi

    # Verificar se existem legendas para manter
    if ! has_subtitles_to_keep "$input_file"; then
        echo "  ℹ️  Nenhuma legenda para manter encontrada (linguagens: $KEEP_LANGS)."
        echo "  🔒 Não será processado (nada para manter)"
        CURRENT_NEW_FILE=""  # Limpar variável global
        return 2  # Sem legendas para manter
    fi

    # Contar legendas a remover
    local remove_count
    remove_count=$(count_subtitles_to_remove "$input_file")

    # Obter tracks de legenda a remover para exibição
    local subs_to_remove
    subs_to_remove=$(get_subtitles_to_remove "$input_file")

    # Mostrar resumo do que será feito
    echo "  📋 Legendas que serão removidas:"
    if [[ $remove_count -eq 0 ]]; then
        echo "    Nenhuma legenda para remover encontrada."
    else
        local displayed_count=0
        while IFS=: read -r track_id language track_name; do
            # Verificar se a linha não está vazia e tem um track_id válido
            if [[ -n "$track_id" && "$track_id" =~ ^[0-9]+$ ]]; then
                format_track_display "$track_id" "$language" "$track_name"
                ((displayed_count++))
            fi
        done <<< "$subs_to_remove"

        # Se não mostramos nenhuma track válida, mas remove_count > 0, há inconsistência
        if [[ $displayed_count -eq 0 && $remove_count -gt 0 ]]; then
            echo "    Nenhuma legenda para remover válida encontrada."
            # Corrigir o remove_count para evitar processamento desnecessário
            remove_count=0
        fi
    fi

    echo ""
    echo "  ✅ Tracks que serão mantidas:"

    # Obter e mostrar tracks que serão mantidas
    local video_tracks_keep
    video_tracks_keep=$(get_track_ids_by_type "$input_file" "video" "all")
    local video_count=0
    while read -r track_id; do
        if [[ -n "$track_id" && "$track_id" =~ ^[0-9]+$ ]]; then
            echo "    - Track $track_id: video"
            ((video_count++))
        fi
    done <<< "$video_tracks_keep"

    local audio_tracks_keep
    audio_tracks_keep=$(get_track_ids_by_type "$input_file" "audio" "all")
    local audio_count=0
    while read -r track_id; do
        if [[ -n "$track_id" && "$track_id" =~ ^[0-9]+$ ]]; then
            echo "    - Track $track_id: audio"
            ((audio_count++))
        fi
    done <<< "$audio_tracks_keep"

    local subtitle_tracks_keep
    subtitle_tracks_keep=$(get_track_ids_by_type "$input_file" "subtitles" "keep")
    local subtitle_count=0
    while read -r track_id; do
        if [[ -n "$track_id" && "$track_id" =~ ^[0-9]+$ ]]; then
            # Obter informações detalhadas da legenda
            local track_info
            track_info=$(mkvmerge -J "$input_file" | jq -r --arg tid "$track_id" '
                .tracks[] |
                select(.id == ($tid | tonumber)) |
                "\(.properties.language // "unknown"):\(.properties.track_name // "")"
            ')
            IFS=: read -r language track_name <<< "$track_info"
            format_track_display "$track_id" "$language" "$track_name"
            ((subtitle_count++))
        fi
    done <<< "$subtitle_tracks_keep"

    # Mostrar contagem resumida
    echo ""
    echo "  📊 Resumo: $video_count vídeo(s), $audio_count áudio(s), $subtitle_count legenda(s) para manter, $remove_count legenda(s) para remover"

    if [[ $DRY_RUN == true ]]; then
        echo ""
        echo "  🔍 MODO SIMULAÇÃO - Nenhum arquivo será modificado"
        echo "  📤 Arquivo de saída seria: $output_file"
        echo "  📝 Comando que seria executado:"
        local mkvmerge_cmd
        mkvmerge_cmd=$(build_mkvmerge_command "$input_file" "$output_file")
        echo "     $mkvmerge_cmd"
        CURRENT_NEW_FILE=""  # Limpar variável global
        return 0
    fi

    # Verificar se arquivo de destino já existe (agora no momento da ação)
    if check_destination_exists "$input_file" "$output_dir"; then
        echo "  ⚠️  Arquivo de destino já existe: $output_file"
        echo "  🔒 Pulando processamento"
        CURRENT_NEW_FILE=""  # Limpar variável global
        return 5  # Destino já existe
    fi

    # Se não há legendas para remover, não precisa fazer nada
    if [[ $remove_count -eq 0 ]]; then
        echo ""
        echo "  ✅ Nenhuma legenda para remover encontrada. Nenhuma ação necessária."

        # Copiar arquivo original para destino usando dd com progresso
        if ! copy_with_progress "$input_file" "$output_file"; then
            CURRENT_NEW_FILE=""  # Limpar variável global
            return 4  # Erro na cópia
        fi

        CURRENT_NEW_FILE=""  # Limpar variável global
        return 3  # Sem legendas para remover
    fi

    echo ""
    echo "  🛠️  Criando arquivo processado: $output_file"

    # Executar mkvmerge
    if execute_mkvmerge "$input_file" "$output_file" 2>/dev/null; then
        echo "  ✅ Arquivo processado criado com sucesso"

        # Verificar se o arquivo foi criado e tem conteúdo
        if [[ -f "$output_file" && -s "$output_file" ]]; then
            echo "  ✅ Processamento concluído com sucesso!"
        else
            echo "  ❌ Erro: Arquivo processado está vazio ou não foi criado corretamente"
            # Remover arquivo inválido
            if [[ -f "$output_file" ]]; then
                rm -f "$output_file"
            fi
            return 4  # Erro
        fi
    else
        echo "  ❌ Erro ao criar arquivo processado"
        # Mostrar o erro real do mkvmerge
        echo "  🔍 Detalhes do erro:"
        execute_mkvmerge "$input_file" "$output_file" 2>&1 | head -5
        # Remover arquivo em caso de erro
        if [[ -f "$output_file" ]]; then
            echo "  🗑️  Removendo arquivo inválido: $(basename "$output_file")"
            rm -f "$output_file"
        fi
        return 4  # Erro
    fi

    # Limpar variável global após conclusão
    CURRENT_NEW_FILE=""
    return 0  # Sucesso
}

# Função para mostrar informações do arquivo
show_file_info() {
    local file="$1"

    echo "📊 Informações do arquivo:"
    echo "  Nome: $(basename "$file")"
    echo "  Tamanho: $(du -h "$file" | cut -f1)"
    echo ""

    # Mostrar todas as tracks de forma formatada
    echo "  Faixas disponíveis:"
    mkvmerge -J "$file" | jq -r '
        .tracks[] |
        "\(.id):\(.type):\(.codec):\(.properties.language // "unknown"):\(.properties.track_name // "")"
    ' | while IFS=: read -r track_id type codec language track_name; do
        if [[ "$type" == "subtitles" ]]; then
            if [[ "$language" != "unknown" ]]; then
                if [[ -n "$track_name" ]]; then
                    echo "    - Track $track_id: $type - $codec [$language] - $track_name"
                else
                    echo "    - Track $track_id: $type - $codec [$language]"
                fi
            fi
        else
            if [[ -n "$track_name" ]]; then
                echo "    - Track $track_id: $type - $codec [$language] - $track_name"
            else
                echo "    - Track $track_id: $type - $codec [$language]"
            fi
        fi
    done
}

# Função para processar diretório
process_directory() {
    local input_dir="$1"
    local output_dir="$2"

    echo "Buscando arquivos MKV em: $input_dir"
    echo "Destino: $output_dir"
    echo "Linguagens a manter: $KEEP_LANGS"
    echo "---"

    # Buscar arquivos MKV
    local mkv_files=()
    for file in "$input_dir"/*.mkv; do
        [[ -f "$file" ]] && mkv_files+=("$file")
    done

    # Se não encontrou com glob, tenta com find (para casos onde o glob pode falhar)
    if [[ ${#mkv_files[@]} -eq 0 ]]; then
        while IFS= read -r -d $'\0' file; do
            mkv_files+=("$file")
        done < <(find "$input_dir" -maxdepth 1 -name "*.mkv" -type f -print0 2>/dev/null)
    fi

    if [[ ${#mkv_files[@]} -eq 0 ]]; then
        echo "Nenhum arquivo MKV encontrado em '$input_dir'"
        return 1
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
    local total_files=${#mkv_files[@]}
    local current=0
    local processed_count=0
    local skipped_count=0
    local skipped_destination_exists_count=0
    local error_count=0

    for file in "${mkv_files[@]}"; do
        # Verificar se foi interrompido antes de processar próximo arquivo
        if [[ $INTERRUPTED == true ]]; then
            echo "❌ Processo abortado pelo usuário"
            return 1
        fi

        ((current++))
        echo "[$current/$total_files]"

        # Processar arquivo e capturar o código de retorno
        process_single_file "$file" "$output_dir"
        local result=$?

        case $result in
            0)  # Sucesso - arquivo foi processado
                ((processed_count++))
                ;;
            2)  # Sem legendas para manter
                ((skipped_count++))
                ;;
            3)  # Sem legendas para remover
                ((skipped_count++))
                ;;
            4)  # Erro
                ((error_count++))
                ;;
            5)  # Destino já existe
                ((skipped_destination_exists_count++))
                ;;
        esac

        # Verificar se foi interrompido após processar arquivo
        if [[ $INTERRUPTED == true ]]; then
            echo "❌ Processo abortado pelo usuário"
            return 1
        fi

        echo
    done

    # Mostrar resumo final
    echo "📈 Resumo do processamento:"
    echo "  ✅ Processados com sucesso: $processed_count"
    echo "  ⏭️  Pulados (sem necessidade): $skipped_count"
    echo "  ⏭️  Pulados (destino existe): $skipped_destination_exists_count"
    echo "  ❌ Erros: $error_count"
    echo "  📊 Total de arquivos: $total_files"
}

# Processar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -in)
            INPUT="$2"
            shift 2
            ;;
        -out)
            OUTPUT="$2"
            shift 2
            ;;
        -keep)
            KEEP_LANGS=$(validate_and_process_languages "$2")
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Erro: Opção desconhecida $1"
            show_usage
            exit 1
            ;;
        *)
            echo "Erro: Argumento inválido $1"
            show_usage
            exit 1
            ;;
    esac
done

# Verificar dependências
check_dependencies

# Validar parâmetros de entrada e saída
validate_input_output "$INPUT" "$OUTPUT"

# Determinar se o target é arquivo ou diretório
if [[ -f "$INPUT" ]]; then
    # É um arquivo
    if check_mkv_file "$INPUT"; then
        # Mostrar informações se verbose
        if [[ $VERBOSE == true ]]; then
            show_file_info "$INPUT"
            echo "---"
        fi

        # Processar arquivo único
        process_single_file "$INPUT" "$OUTPUT"
        result=$?

        if [[ $INTERRUPTED == true ]]; then
            echo "❌ Processo abortado pelo usuário"
            exit 1
        else
            case $result in
                0) echo "✅ Arquivo processado com sucesso!" ;;
                2) echo "⏭️ Arquivo pulado (sem legendas para manter)" ;;
                3) echo "⏭️ Arquivo pulado (sem legendas para remover)" ;;
                4) echo "❌ Erro ao processar arquivo" ;;
                5) echo "⏭️ Arquivo pulado (destino já existe)" ;;
            esac
        fi
    else
        exit 1
    fi
elif [[ -d "$INPUT" ]]; then
    # É um diretório
    process_directory "$INPUT" "$OUTPUT"
    if [[ $INTERRUPTED == true ]]; then
        echo "❌ Processo abortado pelo usuário"
        exit 1
    else
        echo "✅ Processamento em lote concluído!"
    fi
else
    echo "Erro: '$INPUT' não encontrado (não é arquivo nem diretório)"
    show_usage
    exit 1
fi
