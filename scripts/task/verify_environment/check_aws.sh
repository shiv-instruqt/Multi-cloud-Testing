#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# AWS CLI signed in and the S3 bucket reachable
if ! aws s3api head-bucket --bucket "$AWS_BUCKET" >/dev/null 2>&1; then
  echo "Cannot reach S3 bucket $AWS_BUCKET with the configured AWS CLI."
  exit 1
fi
echo "AWS OK: s3://$AWS_BUCKET"
