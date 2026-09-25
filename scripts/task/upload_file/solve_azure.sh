#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

set -e
az storage blob upload --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --file "$UPLOAD_FILE" --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --overwrite --no-progress --output none --only-show-errors
