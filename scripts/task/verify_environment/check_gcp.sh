#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# gcloud signed in and the GCS bucket reachable
if ! gcloud storage buckets describe "gs://$GCP_BUCKET" --format='value(name)' >/dev/null 2>&1; then
  echo "Cannot reach GCS bucket gs://$GCP_BUCKET with the configured gcloud CLI."
  exit 1
fi
echo "GCP OK: gs://$GCP_BUCKET"
