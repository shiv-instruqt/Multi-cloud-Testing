# Your Multi-Cloud Workstation

In this lab you will push **one file** from **one terminal** to three different clouds, then pull it back from each cloud and prove it arrived intact.

| Cloud | Storage service | Your target |
| --- | --- | --- |
| AWS | Amazon S3 | `s3://{{aws_bucket}}` |
| Microsoft Azure | Blob Storage | account `{{azure_account}}`, container `{{azure_container}}` |
| Google Cloud | Cloud Storage (GCS) | `gs://{{gcp_bucket}}` |

## What the setup script already did

Before you got the terminal, the lab setup script:

- Installed the **AWS CLI v2**, the **Azure CLI** (`az`) and the **Google Cloud CLI** (`gcloud`)
- Signed each CLI in with the cloud accounts created for this lab
- Created one bucket or container in each cloud
- Created the file you will upload: `~/multicloud-lab/upload/hello-multicloud.txt`

## Look around

Print a summary of your environment at any time:

```bash
lab-info
```

Confirm each CLI is installed:

```bash
aws --version
az version --query '"azure-cli"' -o tsv
gcloud --version | head -n 1
```

Take a look at the file you are going to push:

```bash
cat ~/multicloud-lab/upload/hello-multicloud.txt
```

Your bucket names are also stored in environment variables, so you can use them in every command:

```bash
echo $AWS_BUCKET
echo $AZURE_STORAGE_ACCOUNT $AZURE_CONTAINER
echo $GCP_BUCKET
```

The **Cloud Credentials** tab has console logins for all three clouds if you want to watch your files appear in the web consoles.

## Check your environment

Click **Check** to confirm all three clouds are ready.

<instruqt-task id="verify_environment"></instruqt-task>
