#!/bin/bash
# Dentro do seu script

SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
SCRIPT_PATH2=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || greadlink -f "${BASH_SOURCE[0]}")

echo "Arquivo atual: $SCRIPT_PATH"
echo "Diretório: $SCRIPT_DIR"
echo "Nome do arquivo: $SCRIPT_NAME"
echo "test: $SCRIPT_PATH2"
