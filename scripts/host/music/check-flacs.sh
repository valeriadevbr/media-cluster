#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../../setup/includes/load-env.sh"
. "$(dirname -- "$0")/../../../setup/includes/pkg-utils.sh"
set +a

LOG_FILE="${ROOT_PATH}/report.csv"
RESOURCES_DIR="${SCRIPTS_PATH}/host/resources"
TARGET_PATH="."
USE_LAC=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --use-lac)
    USE_LAC=1
    shift
    ;;
  *)
    TARGET_PATH="$1"
    shift
    ;;
  esac
done

# Definições Go (Padrão)
ALC_BIN_GO="/tmp/audio-loss-checker"
ALC_DIR_GO="$RESOURCES_DIR/audio-loss-checker"

# Definições LAC
LAC_RES_DIR="$RESOURCES_DIR/lac"
LAC_TMP_DIR="/tmp/lac_tool"
LAC_BIN="$LAC_TMP_DIR/LAC"

cleanup() {
  if [ -d "$LAC_TMP_DIR" ]; then
    rm -f "$LAC_TMP_DIR"/*.wav
  fi
}
trap cleanup EXIT INT TERM

if [ "$USE_LAC" -eq 1 ]; then
  install_sys_pkg "git"
  install_sys_pkg "ffmpeg"
else
  install_sys_pkg "go"
fi

setup_tool_go() {
  local current_dir="$(pwd)"

  if [ ! -f "$ALC_DIR_GO/go.mod" ]; then
    echo "📦 Inicializando submodule..."
    cd "$ROOT_PATH" || exit 1
    local rel_path="${ALC_DIR_GO#"$ROOT_PATH"/}"
    git submodule update --init --recursive "$rel_path"
    cd "$current_dir" || exit 1
  fi

  PATCH_FILE="$RESOURCES_DIR/alc_stricter.patch"
  if [ -f "$PATCH_FILE" ]; then
    cd "$ALC_DIR_GO" || exit 1

    if git apply --check "$PATCH_FILE" 2>/dev/null; then
      echo "🔧 Aplicando patch de sensibilidade..."
      git apply --whitespace=nowarn "$PATCH_FILE"
      rm -f "$ALC_BIN_GO"
    else
      if ! git apply --check --reverse "$PATCH_FILE" 2>/dev/null; then
        echo "⚠️  Aviso: O patch não pode ser aplicado nem revertido."
        echo "          O código upstream pode ter mudado."
      fi
    fi
    cd "$current_dir" || exit 1
  fi

  echo "🔨 Compilando ferramenta (output em /tmp)..."
  cd "$ALC_DIR_GO" || exit 1
  go build -o "$ALC_BIN_GO"
  cd "$current_dir" || exit 1
}

setup_tool_lac() {
  if [ ! -f "$LAC_BIN" ]; then
    echo "📦 Configurando LAC em $LAC_TMP_DIR..."
    mkdir -p "$LAC_TMP_DIR"

    local os_name=$(uname -s)
    local arch_name=$(uname -m)
    local lac_archive=""

    if [ "$os_name" == "Darwin" ]; then
      lac_archive="LAC-macOS-64bit.tar.gz"
    elif [ "$os_name" == "Linux" ] && [ "$arch_name" == "x86_64" ]; then
      lac_archive="LAC-Linux-64bit.tar.gz"
    elif [ "$os_name" == "Linux" ]; then
      lac_archive="LAC-Linux-32bit.tar.gz"
    else
      echo "❌ Erro: Sistema operacional não suportado ($os_name)."
      exit 1
    fi

    echo "   - Detectado: $os_name ($arch_name) -> Usando $lac_archive"
    tar -xzf "$LAC_RES_DIR/$lac_archive" -C "$LAC_TMP_DIR"
    chmod +x "$LAC_BIN"
  fi
}

process_lac() {
  local file="$1"
  local sample_rate="$2"
  local tmp_wav="${LAC_TMP_DIR}/$(basename "$file" .flac).wav"

  ffmpeg -y -nostdin -i "$file" -ar "$sample_rate" -ac 2 -c:a pcm_s16le \
    "$tmp_wav" -v error
  local output=$("$TOOL_BIN" "$tmp_wav")
  local res_lac=$(echo "$output" | grep "Result:" | awk -F ': ' '{print $2}')
  rm -f "$tmp_wav"

  if [[ "$res_lac" == "Clean" ]]; then
    IS_FAKE="OK"
    DETAILS="$res_lac"
  else
    IS_FAKE="FAKE"
    DETAILS="$res_lac"
  fi
}

process_go() {
  local file="$1"
  local result=$("$TOOL_BIN" --json "$file")
  IS_FAKE=$(echo "$result" | grep -o '"status": *"[^"]*"' | cut -d'"' -f4)
  DETAILS=$(echo "$result" | grep -o '"details": *"[^"]*"' | cut -d'"' -f4)
}

if [ "$USE_LAC" -eq 1 ]; then
  setup_tool_lac
  TOOL_BIN="$LAC_BIN"
else
  setup_tool_go
  TOOL_BIN="$ALC_BIN_GO"
fi

echo "Iniciando análise em: $TARGET_PATH"

echo "Arquivo,Status,Freq (Hz),Bits" >"$LOG_FILE"
find "$TARGET_PATH" -type f -name "*.flac" | while read -r arquivo; do
  META=$(ffprobe -v error -select_streams a:0 \
    -show_entries stream=sample_rate,bits_per_raw_sample \
    -of default=noprint_wrappers=1:nokey=1 "$arquivo")
  read -r SAMPLE_RATE BITS <<<$(echo "$META")
  BITS="${BITS:-16}"

  if [ "$USE_LAC" -eq 1 ]; then
    process_lac "$arquivo" "$SAMPLE_RATE"
  else
    process_go "$arquivo"
  fi

  if [ "$IS_FAKE" == "FAKE" ]; then
    STATUS="SUSPEITO"
    echo "❌ $STATUS: $arquivo (${SAMPLE_RATE}Hz / ${BITS}bit) [$DETAILS]"
  else
    STATUS="OK"
    echo "✅ $STATUS: $arquivo (${SAMPLE_RATE}Hz / ${BITS}bit) [$DETAILS]"
  fi

  echo "\"$arquivo\",$STATUS,$SAMPLE_RATE,$BITS" >>"$LOG_FILE"
done

echo "Concluído! Verifique o arquivo $LOG_FILE"
