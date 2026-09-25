#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Azure CLI signed in to the lab subscription and the blob container exists
if ! az account show --query id -o tsv --only-show-errors 2>/dev/null | grep -q "$AZURE_SUBSCRIPTION_ID"; then
  echo "Azure CLI is not signed in to subscription $AZURE_SUBSCRIPTION_ID."
  exit 1
fi
EXISTS=$(az storage container exists --name "$AZURE_CONTAINER" \
  --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --query exists -o tsv --only-show-errors 2>/dev/null)
if [ "$EXISTS" != "true" ]; then
  echo "Blob container $AZURE_CONTAINER was not found in storage account $AZURE_STORAGE_ACCOUNT."
  exit 1
fi
echo "Azure OK: $AZURE_STORAGE_ACCOUNT/$AZURE_CONTAINER"
