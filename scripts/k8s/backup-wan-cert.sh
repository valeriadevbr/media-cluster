#!/bin/bash
set -e

# Configuration
# If CONFIGS_PATH is set, we are likely running manually on the host via wrapper.
# In the cluster, we mount the 'backups' subfolder at /mnt/backups
if [ -n "$CONFIGS_PATH" ]; then
  BASE_PATH="$CONFIGS_PATH/backups"
else
  BASE_PATH="/mnt/backups"
fi

BACKUP_FILE="$BASE_PATH/wan-cert.yaml"
SECRET_NAME="wan-wildcard-tls"
CONTEXT="${1:-}"

KUBECTL_CMD="kubectl"
if [ -n "$CONTEXT" ]; then
  KUBECTL_CMD="kubectl --context $CONTEXT"
fi

echo "⏳ Starting backup and sync for certificate '$SECRET_NAME'..."

# Ensure backup directory exists
mkdir -p "$(dirname "$BACKUP_FILE")"

# Create a temporary file for the cleaned secret
TMP_SECRET=$(mktemp)

# Get and clean the secret from infra namespace
if ! $KUBECTL_CMD get secret "$SECRET_NAME" -n infra -o yaml >"$TMP_SECRET" 2>/dev/null; then
  echo "⚠️ Error: Secret '$SECRET_NAME' not found in namespace 'infra'."
  rm -f "$TMP_SECRET"
  exit 1
fi

# Filter out metadata and system fields to allow clean apply later
grep -vE 'creationTimestamp:|resourceVersion:|uid:|selfLink:|managedFields:|ownerReferences:' "$TMP_SECRET" >"${BACKUP_FILE}.tmp"

# Finalize the backup file
mv "${BACKUP_FILE}.tmp" "$BACKUP_FILE"
echo "✅ Backup saved to: $BACKUP_FILE"

echo "✨ Done!"
rm -f "$TMP_SECRET"
