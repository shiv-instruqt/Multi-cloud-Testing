#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that the learner downloaded hello-multicloud.txt from Google Cloud Storage into
# ~/multicloud-lab/downloads/gcp/ and that it arrived intact: its SHA-256 must
# match the original upload file AND the object currently stored in Google Cloud Storage.
DOWNLOADED="$LAB_HOME/downloads/gcp/$LAB_FILE"
if [ ! -f "$DOWNLOADED" ]; then
  echo "$DOWNLOADED not found. Download it with: gcloud storage cp gs://$GCP_BUCKET/$LAB_FILE $LAB_HOME/downloads/gcp/"
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
if ! gcloud storage cp "gs://$GCP_BUCKET/$LAB_FILE" "$TMP/object" --quiet >/dev/null 2>&1; then
  echo "Could not read gs://$GCP_BUCKET/$LAB_FILE - complete the upload step first."
  exit 1
fi
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$CLOUD" != "$RECEIVED" ]; then
  echo "Your downloaded file does not match the object stored in Google Cloud Storage."
  exit 1
fi
echo "Received from Google Cloud Storage successfully (sha256 $RECEIVED)"
