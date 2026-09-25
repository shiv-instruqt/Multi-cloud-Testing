#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that hello-multicloud.txt is in the S3 bucket and is byte-identical
# to the learner's local file (the object is fetched and SHA-256 compared).
if [ ! -s "$UPLOAD_FILE" ]; then
  echo "Local file $UPLOAD_FILE is missing or empty."
  exit 1
fi
if ! aws s3api head-object --bucket "$AWS_BUCKET" --key "$LAB_FILE" >/dev/null 2>&1; then
  echo "s3://$AWS_BUCKET/$LAB_FILE was not found. Upload it with: aws s3 cp $UPLOAD_FILE s3://$AWS_BUCKET/"
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
aws s3 cp "s3://$AWS_BUCKET/$LAB_FILE" "$TMP/object" --only-show-errors || exit 1
LOCAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$LOCAL" != "$CLOUD" ]; then
  echo "The S3 object does not match your local file (local $LOCAL, s3 $CLOUD). Upload it again."
  exit 1
fi
echo "AWS upload verified (sha256 $CLOUD)"
