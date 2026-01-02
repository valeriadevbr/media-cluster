#!/bin/bash

configure_pkg_manager() {
  if [[ "$OS" == "Darwin" ]]; then
    export HOMEBREW_NO_ENV_HINTS=1
    export HOMEBREW_NO_AUTO_UPDATE=1
  fi
}

update_sys_pkg_cache() {
  if [[ "$OS" != "Darwin" ]]; then
    if command -v apt-get &>/dev/null; then
      if [ -z "$APT_UPDATED" ]; then
        echo "📦 Atualizando cache do apt..."
        sudo apt-get update
        export APT_UPDATED=true
      fi
    elif command -v apk &>/dev/null; then
      if [ -z "$APK_UPDATED" ]; then
        echo "📦 Atualizando cache do apk..."
        sudo apk update
        export APK_UPDATED=true
      fi
    fi
  fi
}

install_sys_pkg() {
  local pkg="$1"
  local mac_pkg="${2:-$pkg}"
  configure_pkg_manager
  update_sys_pkg_cache

  if [[ "$OS" == "Darwin" ]]; then
    brew install "$mac_pkg" -q || brew link --force "$mac_pkg"
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y "$pkg"
  elif command -v apk &>/dev/null; then
    sudo apk add --no-cache "$pkg"
  else
    echo "⚠️  Gerenciador de pacotes não suportado. Instale '$pkg' manualmente."
  fi
}
