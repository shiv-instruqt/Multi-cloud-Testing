#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that the learner downloaded hello-multicloud.txt from Azure Blob Storage into
# ~/multicloud-lab/downloads/azure/ and that it arrived intact: its SHA-256 must
# match the original upload file AND the object currently stored in Azure Blob Storage.
DOWNLOADED="$LAB_HOME/downloads/azure/$LAB_FILE"
if [ ! -f "$DOWNLOADED" ]; then
  echo "$DOWNLOADED not found. Download it with az storage blob download (see the instructions)."
  exit 1
fi
if [ ! -s "$DOWNLOADED" ]; then
  echo "$DOWNLOADED is empty - the download did not complete."
  exit 1
fi
ORIGINAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
RECEIVED=$(sha256sum "$DOWNLOADED" | cut -d' ' -f1)
if [ "$ORIGINAL" != "$RECEIVED" ]; then
  echo "Checksum mismatch: original $ORIGINAL, received $RECEIVED."
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if ! az storage blob download --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --file "$TMP/object" --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --no-progress --output none --only-show-errors; then
  echo "Could not read blob $LAB_FILE from container $AZURE_CONTAINER - complete the upload step first."
  exit 1
fi
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$CLOUD" != "$RECEIVED" ]; then
  echo "Your downloaded file does not match the object stored in Azure Blob Storage."
  exit 1
fi
echo "Received from Azure Blob Storage successfully (sha256 $RECEIVED)"
