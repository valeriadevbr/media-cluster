#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../setup/includes/load-env.sh"
set +a

# Script para configurar ACLs na pasta media com propagação para filhos
# Você: RWX (read, write, execute)
# Grupo: RW (read, write)
# Outros: R (read)

# Verifica se a pasta existe
if [ ! -d "$MEDIA_PATH" ]; then
  echo "Erro: Pasta $MEDIA_PATH não encontrada"
  exit 1
fi

echo "Configurando permissões para $MEDIA_PATH..."

# Remove ACLs existentes recursivamente
echo "Removendo ACLs existentes..."
find "$MEDIA_PATH" -exec chmod -N {} \; 2>/dev/null || true

# Configura permissões POSIX padrão recursivamente
# X maiúsculo = execute apenas em diretórios, não em arquivos
echo "Aplicando permissões POSIX base..."
chmod -R u+rwX,g+rwX,o+rX "$MEDIA_PATH"

# Adiciona setgid APENAS em diretórios para herança de grupo
# Diretórios: rwxrwsr-x (2775)
# Arquivos: rw-rw-r-- (664)
echo "Aplicando setgid em diretórios..."
find "$MEDIA_PATH" -type d -exec chmod g+s {} \;

if [[ "$OS" == "Darwin" ]]; then
  echo "🍏 Removendo atributos de quarentena do macOS..."
  xattr -r -d com.apple.quarantine "$MEDIA_PATH" 2>/dev/null || true
  xattr -r -d com.apple.provenance "$MEDIA_PATH" 2>/dev/null || true
fi

echo ""
echo "✅ Permissões configuradas com sucesso!"
echo ""
echo "Permissões da pasta principal:"
ls -ld "$MEDIA_PATH"
echo ""
echo "Novos arquivos e pastas herdarão automaticamente estas permissões."
