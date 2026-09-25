# Download From Azure Blob Storage

Next, pull the file back from container `{{azure_container}}` in storage account `{{azure_account}}` into `~/multicloud-lab/downloads/azure/`:

```bash
az storage blob download \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --account-key $AZURE_STORAGE_KEY \
  --auth-mode key \
  --container-name $AZURE_CONTAINER \
  --name hello-multicloud.txt \
  --file ~/multicloud-lab/downloads/azure/hello-multicloud.txt
```

Compare it with the original:

```bash
sha256sum ~/multicloud-lab/upload/hello-multicloud.txt ~/multicloud-lab/downloads/azure/hello-multicloud.txt
```

## Verify

Click **Check**. The check confirms the downloaded file exists and that its SHA-256 matches both the original file and the blob currently stored in Azure.

<instruqt-task id="download_azure"></instruqt-task>
