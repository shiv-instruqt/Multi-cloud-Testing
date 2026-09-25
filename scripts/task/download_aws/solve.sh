#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

set -e
mkdir -p "$LAB_HOME/downloads/aws"
if ! aws s3api head-object --bucket "$AWS_BUCKET" --key "$LAB_FILE" >/dev/null 2>&1; then
  aws s3 cp "$UPLOAD_FILE" "s3://$AWS_BUCKET/$LAB_FILE" --only-show-errors
fi
aws s3 cp "s3://$AWS_BUCKET/$LAB_FILE" "$LAB_HOME/downloads/aws/$LAB_FILE" --only-show-errors
