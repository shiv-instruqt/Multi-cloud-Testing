# Multi-Cloud Storage Lab (Instruqt 2.0 Labs, HCL)

One Ubuntu workstation + one terminal + an AWS account, an Azure subscription and a Google Cloud project.
The learner pushes `hello-multicloud.txt` to an S3 bucket, an Azure Blob container and a GCS bucket,
then downloads it back from each cloud separately. Check scripts verify every step with SHA-256 checksums.

`instruqt lab validate` → **Lab is valid** (CLI version 2426-665ffd3).

## Folder structure

```
multicloud-storage-lab/
├── main.hcl                 # Lab metadata, time limit, chapters and pages
├── cloud.hcl                # aws_account, azure_subscription, google_project
├── sandbox.hcl              # Ubuntu 22.04 workstation + setup exec resource
├── tabs.hcl                 # Terminal + Cloud Credentials tab
├── layouts.hcl              # Instructions (left) | Terminal + Credentials (right)
├── pages.hcl                # Pages, bucket names shown via exec output variables
├── tasks.hcl                # 5 tasks: verify, upload, download x3
├── instructions/            # Learner markdown, one file per page
│   ├── 01-introduction.md
│   ├── 02-upload-file.md
│   ├── 03-download-aws.md
│   ├── 04-download-azure.md
│   ├── 05-download-gcp.md
│   └── 06-summary.md
└── scripts/
    ├── exec/
    │   └── setup_workstation/script.sh     # installs CLIs, logs in, creates buckets
    └── task/
        ├── verify_environment/  check_aws.sh  check_azure.sh  check_gcp.sh
        ├── upload_file/         check_*.sh + solve_*.sh (one pair per cloud)
        ├── download_aws/        check.sh  solve.sh
        ├── download_azure/      check.sh  solve.sh
        └── download_gcp/        check.sh  solve.sh
```

## What the setup script does (`scripts/exec/setup_workstation/script.sh`)

1. Installs AWS CLI v2, Azure CLI (Microsoft install script) and Google Cloud CLI (Google apt repo).
2. Signs in: AWS with the `student` IAM user keys, Azure with the `automation` service principal,
   GCP with the `automation` service account key.
3. Creates globally unique storage per cloud:
   - `s3://mc-lab-aws-<suffix>` (us-east-1)
   - resource group `multicloud-lab-rg`, storage account `mclab<suffix>`, container `multicloud-lab` (eastus)
   - `gs://mc-lab-gcp-<suffix>` (us-central1)
4. Creates `~/multicloud-lab/upload/hello-multicloud.txt` and `~/multicloud-lab/downloads/{aws,azure,gcp}/`.
5. Writes `/root/.multicloud/env` (sourced by `~/.bashrc` and every check script) and a `lab-info` command.
6. Writes bucket names to `EXEC_OUTPUT` so the instructions can show them.

Every cloud call is retried, because new IAM keys, service principals and project APIs take a few minutes to propagate.
The script is idempotent (safe to re-run) and logs to `/var/log/multicloud-setup.log` inside the workstation.

## Learner flow and checks

| Page | Task | What the check verifies |
| --- | --- | --- |
| Your Multi-Cloud Workstation | `verify_environment` | Each CLI is signed in and its bucket/container exists |
| Upload | `upload_file` (3 conditions) | Object exists in each cloud **and** its SHA-256 equals the local file |
| Download From AWS S3 | `download_aws` | `downloads/aws/hello-multicloud.txt` SHA-256 = original = S3 object |
| Download From Azure | `download_azure` | `downloads/azure/hello-multicloud.txt` SHA-256 = original = blob |
| Download From GCS | `download_gcp` | `downloads/gcp/hello-multicloud.txt` SHA-256 = original = GCS object |

Every condition has a solve script, so skipping works.

## Push to GitHub and import

The Labs **Import lab** flow reads HCL from a GitHub repo. Put the **contents** of this folder at the **root** of the repo
(earlier builds had bugs importing from a sub-folder).

```bash
cd multicloud-storage-lab
git init && git branch -m main
git add . && git commit -m "Multi-cloud storage lab"
git remote add origin git@github.com:<org>/multicloud-storage-lab.git
git push -u origin main
```

Then in Instruqt: **Labs → Import lab** → select the repository → branch `main` → folder `/` → **Import lab**.
After that, every `git push` to `main` syncs the lab.

Optional local check before pushing: `instruqt lab validate`.

## Before you play it

- **Cloud provider settings**: the org's cloud provider configuration must allow the services and roles used here:
  AWS `s3` + `AmazonS3FullAccess`; Azure `Microsoft.Storage` + `Contributor`; GCP `storage.googleapis.com` + `roles/storage.admin`.
- **Start-up time**: provisioning three cloud accounts plus installing three CLIs takes roughly 8-15 minutes. The time limit is 1h30m.
- **References must be positional**: cloud users are referenced as `user.0`, `service_principal.0`, `service_account.0`.
  The name form (`user.student`) fails validation today (tracked in ENG-883 / UNA-625).
- **No dollar-brace in scripts**: the scripts deliberately use `$VAR` rather than the brace form, so HCL interpolation can never touch them.

## Troubleshooting

| Symptom | Where to look |
| --- | --- |
| Lab fails to start | Lab logs; inside the workstation `/var/log/multicloud-setup.log` |
| `verify_environment` fails | Run `lab-info`, then `aws s3 ls`, `az account show`, `gcloud auth list` |
| Azure login keeps retrying | Service principal still replicating; the script retries for ~5 minutes |
| Bucket names show blank in instructions | Setup exec did not finish; check the exec output keys `AWS_BUCKET`, `AZURE_STORAGE_ACCOUNT`, `AZURE_CONTAINER`, `GCP_BUCKET` |
