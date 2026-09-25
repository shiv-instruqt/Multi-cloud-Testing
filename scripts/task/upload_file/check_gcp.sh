#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that hello-multicloud.txt is in the GCS bucket and is byte-identical
# to the learner's local file.
if [ ! -s "$UPLOAD_FILE" ]; then
  echo "Local file $UPLOAD_FILE is missing or empty."
  exit 1
fi
if ! gcloud storage objects describe "gs://$GCP_BUCKET/$LAB_FILE" --format='value(name)' >/dev/null 2>&1; then
  echo "gs://$GCP_BUCKET/$LAB_FILE was not found. Upload it with: gcloud storage cp $UPLOAD_FILE gs://$GCP_BUCKET/"
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
gcloud storage cp "gs://$GCP_BUCKET/$LAB_FILE" "$TMP/object" --quiet >/dev/null 2>&1 || exit 1
LOCAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$LOCAL" != "$CLOUD" ]; then
  echo "The GCS object does not match your local file (local $LOCAL, gcs $CLOUD). Upload it again."
  exit 1
fi
echo "GCP upload verified (sha256 $CLOUD)"
