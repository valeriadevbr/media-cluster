#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../setup/includes/load-env.sh"
. "$(dirname -- "$0")/../../setup/includes/pkg-utils.sh"
set +a

TARGET_PATH="${1:-.}"
LOG_FILE="${ROOT_PATH}/report.csv"
RESOURCES_DIR="${SCRIPTS_PATH}/host/resources"
ALC_DIR="$RESOURCES_DIR/audio-loss-checker"
ALC_BIN="$ALC_DIR/audio-loss-checker"

install_sys_pkg "git"
install_sys_pkg "go"

setup_tool() {
  local current_dir="$(pwd)"

  if [ ! -f "$ALC_DIR/go.mod" ]; then
    echo "📦 Inicializando submodule..."
    cd "$ROOT_PATH" || exit 1
    local rel_path="${ALC_DIR#"$ROOT_PATH"/}"
    git submodule update --init --recursive "$rel_path"
    cd "$current_dir" || exit 1
  fi

  PATCH_FILE="$RESOURCES_DIR/alc_stricter.patch"
  if [ -f "$PATCH_FILE" ]; then
    cd "$ALC_DIR" || exit 1

    # Check if patch is needed
    if git apply --check "$PATCH_FILE" 2>/dev/null; then
      echo "🔧 Aplicando patch de sensibilidade..."
      git apply "$PATCH_FILE"
      # Force rebuild since code changed
      rm -f "$ALC_BIN"
    else
      # If check fails, verify if it is already applied
      if ! git apply --check --reverse "$PATCH_FILE" 2>/dev/null; then
        echo "⚠️  Aviso: O patch não pode ser aplicado nem revertido. O código upstream pode ter mudado."
      fi
    fi
    cd "$current_dir" || exit 1
  fi

  if [ ! -f "$ALC_BIN" ]; then
    echo "🔨 Compilando ferramenta..."
    cd "$ALC_DIR" || exit 1
    go build -o audio-loss-checker
    cd "$current_dir" || exit 1
  fi
}

echo "Arquivo,Status,Detalhes" >"$LOG_FILE"

setup_tool

echo "Iniciando análise em: $TARGET_PATH"

find "$TARGET_PATH" -type f -name "*.flac" | while read -r arquivo; do
  RESULT=$("$ALC_BIN" --json "$arquivo")
  IS_FAKE=$(echo "$RESULT" | grep -o '"status": *"[^"]*"' | cut -d'"' -f4)
  DETAILS=$(echo "$RESULT" | grep -o '"details": *"[^"]*"' | cut -d'"' -f4)

  if [ "$IS_FAKE" == "FAKE" ]; then
    STATUS="SUSPEITO"
    echo "❌ $STATUS: $arquivo"
  else
    STATUS="OK"
    echo "✅ $STATUS: $arquivo"
  fi

  echo "\"$arquivo\",$STATUS,\"$DETAILS\"" >>"$LOG_FILE"
done

echo "Concluído! Verifique o arquivo $LOG_FILE"
