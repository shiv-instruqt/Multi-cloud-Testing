# Your Multi-Cloud Workstation

In this lab you will push **one file** from **one terminal** to two clouds, then pull it back from each cloud and prove it arrived intact.

> **Note:** Azure is temporarily disabled in this version of the lab. It will be added back later.

| Cloud | Storage service | Your target |
| --- | --- | --- |
| AWS | Amazon S3 | `s3://{{aws_bucket}}` |
| Google Cloud | Cloud Storage (GCS) | `gs://{{gcp_bucket}}` |

## What the setup script already did

Before you got the terminal, the lab setup script:

- Installed the **AWS CLI v2** and the **Google Cloud CLI** (`gcloud`)
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
gcloud --version | head -n 1
```

Take a look at the file you are going to push:

```bash
cat ~/multicloud-lab/upload/hello-multicloud.txt
```

Your bucket names are also stored in environment variables, so you can use them in every command:

```bash
echo $AWS_BUCKET
echo $GCP_BUCKET
```

The **Cloud Credentials** tab has console logins for both clouds if you want to watch your files appear in the web consoles.

## Check your environment

Click **Check** to confirm both clouds are ready.

<instruqt-task id="verify_environment"></instruqt-task>
