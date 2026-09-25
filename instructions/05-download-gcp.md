# Download From Google Cloud Storage

Finally, pull the file back from `gs://{{gcp_bucket}}` into `~/multicloud-lab/downloads/gcp/`:

```bash
gcloud storage cp gs://$GCP_BUCKET/hello-multicloud.txt ~/multicloud-lab/downloads/gcp/
```

Compare it with the original:

```bash
sha256sum ~/multicloud-lab/upload/hello-multicloud.txt ~/multicloud-lab/downloads/gcp/hello-multicloud.txt
```

## Verify

Click **Check**. The check confirms the downloaded file exists and that its SHA-256 matches both the original file and the object currently stored in GCS.

<instruqt-task id="download_gcp"></instruqt-task>
