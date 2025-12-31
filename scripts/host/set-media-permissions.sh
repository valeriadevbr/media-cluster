#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../setup/includes/load-env.sh"
set +a

if [[ "$OS" == "Darwin" ]]; then
  echo "🔓 Removendo flag 'uchg' (User Immutable)..."
  chflags -R nouchg "$MEDIA_PATH"
fi

echo "📄 Ajustando permissões de ARQUIVOS (644)..."
find "$MEDIA_PATH" -type f -exec chmod 644 {} \;

echo "📂 Ajustando permissões de DIRETÓRIOS (755)..."
find "$MEDIA_PATH" -type d -exec chmod 755 {} \;

if [[ "$OS" == "Darwin" ]]; then
  echo "🍏 Removendo atributos de quarentena do macOS..."
  xattr -r -d com.apple.quarantine "$MEDIA_PATH" 2>/dev/null || true
  xattr -r -d com.apple.provenance "$MEDIA_PATH" 2>/dev/null || true
fi

echo "✅ Permissões aplicadas com sucesso em: $MEDIA_PATH"
