#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../includes/load-env.sh"
. "$(dirname -- "$0")/../includes/pkg-utils.sh"
set +a

if ! command -v rclone &>/dev/null; then
  echo "Instalando rclone..."
  install_sys_pkg "rclone"
fi

while [[ $# -gt 0 ]]; do
  case $1 in
  -from)
    FROM="$2"
    shift 2
    ;;
  -to)
    TO="$2"
    shift 2
    ;;
  *)
    echo "Argumento desconhecido: $1"
    exit 1
    ;;
  esac
done

if [ -z "$FROM" ] || [ -z "$TO" ]; then
  echo "Uso: $0 -from <origem> -to <destino>"
  exit 1
fi

if [ ! -d "$FROM" ]; then
  echo "ERRO CRÍTICO: O diretório de origem '$FROM' não existe ou não está montado."
  exit 1
fi

if [ -z "$(ls -A "$FROM" 2>/dev/null)" ]; then
  echo "ERRO CRÍTICO: A origem '$FROM' está completamente vazia. Abortando para proteger o destino."
  exit 1
fi

if [[ "$TO" == "$FROM" ]] || [[ "$TO" == "$FROM"/* ]] || [[ "$FROM" == "$TO"/* ]]; then
  echo "ERRO CRÍTICO: Origem e destino não podem se sobrepor. Isso causaria escrita na pasta de origem."
  exit 1
fi

if [[ "$FROM" == *"Backup"* ]] || [[ "$TO" != *"Backup"* ]]; then
  echo "ERRO CRÍTICO: '$TO' não parece ser o disco de Backup ou você inverteu os argumentos!"
  echo "Para garantir que a Origem ($FROM) nunca seja alterada, o script foi abortado."
  exit 1
fi

mkdir -p "$TO"

echo "Iniciando espelhamento de $FROM para $TO usando rclone..."

sudo rclone sync "$FROM" "$TO" \
  --progress \
  --modify-window=1s \
  --inplace \
  --transfers=1 \
  --checkers=1 \
  --metadata \
  --metadata-exclude "macos-*" \
  --metadata-exclude "xattr" \
  --create-empty-src-dirs \
  --exclude ".DS_Store" \
  --exclude "._*"
echo "Espelhamento concluído com sucesso!"
