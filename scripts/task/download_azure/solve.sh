#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

set -e
mkdir -p "$LAB_HOME/downloads/azure"
AZ_AUTH="--account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_KEY --auth-mode key --only-show-errors"
EXISTS=$(az storage blob exists --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" $AZ_AUTH --query exists -o tsv 2>/dev/null || true)
if [ "$EXISTS" != "true" ]; then
  az storage blob upload --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
    --file "$UPLOAD_FILE" $AZ_AUTH --overwrite --no-progress --output none
fi
az storage blob download --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --file "$LAB_HOME/downloads/azure/$LAB_FILE" $AZ_AUTH --no-progress --output none
