#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

set -e
mkdir -p "$LAB_HOME/downloads/gcp"
if ! gcloud storage objects describe "gs://$GCP_BUCKET/$LAB_FILE" --format='value(name)' >/dev/null 2>&1; then
  gcloud storage cp "$UPLOAD_FILE" "gs://$GCP_BUCKET/$LAB_FILE" --quiet
fi
gcloud storage cp "gs://$GCP_BUCKET/$LAB_FILE" "$LAB_HOME/downloads/gcp/$LAB_FILE" --quiet
