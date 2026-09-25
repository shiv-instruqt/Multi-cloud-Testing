# Push the File to All Three Clouds

Now upload `hello-multicloud.txt` from your terminal to each cloud. Keep the object name `hello-multicloud.txt` everywhere.

Start in the lab folder:

```bash
cd ~/multicloud-lab
```

> Want to use your own content? Edit `upload/hello-multicloud.txt` **before** you upload. The check compares each cloud copy with your local file, so if you change it later, upload it again.

## 1. AWS S3

Upload to `s3://{{aws_bucket}}`:

```bash
aws s3 cp upload/hello-multicloud.txt s3://$AWS_BUCKET/
```

Confirm it is there:

```bash
aws s3 ls s3://$AWS_BUCKET/
```

## 2. Azure Blob Storage

Upload to container `{{azure_container}}` in storage account `{{azure_account}}`:

```bash
az storage blob upload \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --account-key $AZURE_STORAGE_KEY \
  --auth-mode key \
  --container-name $AZURE_CONTAINER \
  --name hello-multicloud.txt \
  --file upload/hello-multicloud.txt \
  --overwrite
```

Confirm it is there:

```bash
az storage blob list \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --account-key $AZURE_STORAGE_KEY \
  --auth-mode key \
  --container-name $AZURE_CONTAINER \
  --query "[].name" -o tsv
```

## 3. Google Cloud Storage

Upload to `gs://{{gcp_bucket}}`:

```bash
gcloud storage cp upload/hello-multicloud.txt gs://$GCP_BUCKET/
```

Confirm it is there:

```bash
gcloud storage ls gs://$GCP_BUCKET/
```

## Verify

Click **Check**. For each cloud, the check script downloads the stored object to a temporary folder and compares its SHA-256 checksum with your local file.

<instruqt-task id="upload_file"></instruqt-task>
