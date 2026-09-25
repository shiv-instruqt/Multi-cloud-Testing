#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that hello-multicloud.txt is in the Azure Blob container and is
# byte-identical to the learner's local file.
if [ ! -s "$UPLOAD_FILE" ]; then
  echo "Local file $UPLOAD_FILE is missing or empty."
  exit 1
fi
EXISTS=$(az storage blob exists --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --query exists -o tsv --only-show-errors 2>/dev/null)
if [ "$EXISTS" != "true" ]; then
  echo "Blob $LAB_FILE was not found in container $AZURE_CONTAINER."
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
az storage blob download --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --file "$TMP/object" --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --no-progress --output none --only-show-errors || exit 1
LOCAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$LOCAL" != "$CLOUD" ]; then
  echo "The Azure blob does not match your local file (local $LOCAL, blob $CLOUD). Upload it again with --overwrite."
  exit 1
fi
echo "Azure upload verified (sha256 $CLOUD)"
