#!/bin/bash
set -e
set -a
. "$(dirname -- "$0")/../../setup/includes/load-env.sh"
set +a

"${SETUP_PATH}/utils/folder-mirror.sh" -from "${MEDIA_PATH}/Music" -to "${BACKUP_PATH}/media/Music"
