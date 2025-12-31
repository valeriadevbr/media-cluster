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
set +a
