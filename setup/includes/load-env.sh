set -a
if [ -n "$BASH_SOURCE" ]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$BASH_SOURCE")" && pwd)"
elif [ -n "$ZSH_VERSION" ]; then
  SCRIPT_DIR="$(eval 'echo "${${(%):-%x}:A:h}"')"
else
  SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
fi

source "${SCRIPT_DIR}/../.env"
OS="$(uname)"
PUID=$(id -u)
PGID=$(id -g)
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
  INFRA_CLUSTER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${INFRA_CLUSTER_NAME}-control-plane" 2>/dev/null || echo "")
fi
set +a
