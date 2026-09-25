#!/bin/bash
# Restores the Instruqt 2.0 multi-cloud storage lab (AWS + Azure + GCP).
# Usage: bash restore_multicloud_lab.sh "/path/to/target/folder"
# Creates <target>/multicloud-storage-lab/ with every file, scripts executable.
set -e
TARGET="$1"
if [ -z "$TARGET" ]; then TARGET="."; fi
ROOT="$TARGET/multicloud-storage-lab"
mkdir -p "$ROOT"
cd "$ROOT"

mkdir -p "."
cat > ".gitattributes" <<'__MCLAB_EOF__'
*.sh text eol=lf
*.hcl text eol=lf
*.md text eol=lf
__MCLAB_EOF__

mkdir -p "."
cat > "README.md" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "."
cat > "cloud.hcl" <<'__MCLAB_EOF__'
# -----------------------------------------------------------------------------
# Cloud accounts - one per provider.
#
# IMPORTANT (Labs 2.0 known limitation, ENG-883 / UNA-624 / UNA-625):
# user / service_account / service_principal blocks must be referenced by
# POSITION (user.0, service_account.0, service_principal.0), not by name.
# The name-keyed form shown in parts of the docs fails `instruqt lab validate`.
# -----------------------------------------------------------------------------

# AWS - IAM user "student" with S3 access. Its access keys configure the CLI.
resource "aws_account" "multicloud" {
  regions  = ["us-east-1"]
  services = ["s3"]

  tags = {
    Purpose = "multicloud-storage-lab"
  }

  user "student" {
    managed_policies = [
      "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    ]
  }
}

# Azure - Contributor lets the setup create the resource group, the storage
# account and read the account key used for blob upload/download.
resource "azure_subscription" "multicloud" {
  regions  = ["eastus"]
  services = ["Microsoft.Storage"]

  tags = {
    Purpose = "multicloud-storage-lab"
  }

  user "student" {
    roles = ["Contributor"]
  }

  service_principal "automation" {
    roles = ["Contributor"]
  }
}

# Google Cloud - service account with Storage Admin configures gcloud.
resource "google_project" "multicloud" {
  regions  = ["us-central1"]
  services = ["storage.googleapis.com"]

  labels = {
    purpose = "multicloud-storage-lab"
  }

  user "student" {
    roles = ["roles/storage.admin"]
  }

  service_account "automation" {
    roles = ["roles/storage.admin"]
  }
}
__MCLAB_EOF__

mkdir -p "instructions"
cat > "instructions/01-introduction.md" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "instructions"
cat > "instructions/02-upload-file.md" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "instructions"
cat > "instructions/03-download-aws.md" <<'__MCLAB_EOF__'
# Download From AWS S3

Now pull the file back from each cloud, one at a time, into its own folder. Start with S3.

Download the object from `s3://{{aws_bucket}}` into `~/multicloud-lab/downloads/aws/`:

```bash
aws s3 cp s3://$AWS_BUCKET/hello-multicloud.txt ~/multicloud-lab/downloads/aws/
```

Compare it with the original:

```bash
sha256sum ~/multicloud-lab/upload/hello-multicloud.txt ~/multicloud-lab/downloads/aws/hello-multicloud.txt
```

Both lines should show the same checksum.

## Verify

Click **Check**. The check confirms the downloaded file exists and that its SHA-256 matches both the original file and the object currently stored in S3.

<instruqt-task id="download_aws"></instruqt-task>
__MCLAB_EOF__

mkdir -p "instructions"
cat > "instructions/04-download-azure.md" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "instructions"
cat > "instructions/05-download-gcp.md" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "instructions"
cat > "instructions/06-summary.md" <<'__MCLAB_EOF__'
# Summary

You moved the same file through three clouds from a single terminal:

| Step | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Upload | `aws s3 cp` | `az storage blob upload` | `gcloud storage cp` |
| Download | `aws s3 cp` | `az storage blob download` | `gcloud storage cp` |

All three copies are checked the same way: a SHA-256 checksum of the downloaded file must match the original.

See every copy side by side:

```bash
tree ~/multicloud-lab
sha256sum ~/multicloud-lab/upload/* ~/multicloud-lab/downloads/*/*
```

The cloud accounts and everything in them are removed automatically when the lab ends.
__MCLAB_EOF__

mkdir -p "."
cat > "layouts.hcl" <<'__MCLAB_EOF__'
resource "layout" "workspace" {
  column {
    width = "40"
    instructions {}
  }

  column {
    width = "60"

    tab "terminal" {
      title  = "Terminal"
      target = resource.terminal.workstation
      active = true
    }

    tab "credentials" {
      title  = "Cloud Credentials"
      target = resource.cloud_credentials.multicloud
    }
  }
}
__MCLAB_EOF__

mkdir -p "."
cat > "main.hcl" <<'__MCLAB_EOF__'
resource "lab" "multicloud_storage" {
  title       = "Multi-Cloud Storage: Push and Pull Across AWS, Azure and GCP"
  description = "Upload one file from a single terminal to an AWS S3 bucket, an Azure Blob container and a Google Cloud Storage bucket, then download it back from each cloud and verify it arrived intact."
  tags        = ["aws", "azure", "gcp", "storage", "multi-cloud"]

  settings {
    timelimit {
      duration   = "1h30m"
      extend     = "15m"
      show_timer = true
    }

    idle {
      enabled      = true
      timeout      = "30m"
      show_warning = true
    }
  }

  layout = resource.layout.workspace

  content {
    chapter "getting_started" {
      title = "Getting Started"

      page "introduction" {
        title     = "Your Multi-Cloud Workstation"
        reference = resource.page.introduction
      }
    }

    chapter "upload" {
      title = "Push the File to All Three Clouds"

      page "upload_file" {
        title     = "Upload to S3, Blob Storage and GCS"
        reference = resource.page.upload_file
      }
    }

    chapter "download" {
      title = "Pull the File Back From Each Cloud"

      page "download_aws" {
        title     = "Download From AWS S3"
        reference = resource.page.download_aws
      }

      page "download_azure" {
        title     = "Download From Azure Blob Storage"
        reference = resource.page.download_azure
      }

      page "download_gcp" {
        title     = "Download From Google Cloud Storage"
        reference = resource.page.download_gcp
      }
    }

    chapter "wrap_up" {
      title = "Wrap Up"

      page "summary" {
        title     = "Summary"
        reference = resource.page.summary
      }
    }
  }
}
__MCLAB_EOF__

mkdir -p "."
cat > "pages.hcl" <<'__MCLAB_EOF__'
# Bucket names are generated at runtime by the setup script and passed to the
# instructions through the exec output (EXEC_OUTPUT -> page variables).

resource "page" "introduction" {
  title = "Your Multi-Cloud Workstation"
  file  = "instructions/01-introduction.md"

  variables = {
    aws_bucket      = resource.exec.setup_workstation.output.AWS_BUCKET
    azure_account   = resource.exec.setup_workstation.output.AZURE_STORAGE_ACCOUNT
    azure_container = resource.exec.setup_workstation.output.AZURE_CONTAINER
    gcp_bucket      = resource.exec.setup_workstation.output.GCP_BUCKET
  }

  activities = {
    "verify_environment" = resource.task.verify_environment
  }
}

resource "page" "upload_file" {
  title = "Upload to S3, Blob Storage and GCS"
  file  = "instructions/02-upload-file.md"

  variables = {
    aws_bucket      = resource.exec.setup_workstation.output.AWS_BUCKET
    azure_account   = resource.exec.setup_workstation.output.AZURE_STORAGE_ACCOUNT
    azure_container = resource.exec.setup_workstation.output.AZURE_CONTAINER
    gcp_bucket      = resource.exec.setup_workstation.output.GCP_BUCKET
  }

  activities = {
    "upload_file" = resource.task.upload_file
  }
}

resource "page" "download_aws" {
  title = "Download From AWS S3"
  file  = "instructions/03-download-aws.md"

  variables = {
    aws_bucket = resource.exec.setup_workstation.output.AWS_BUCKET
  }

  activities = {
    "download_aws" = resource.task.download_aws
  }
}

resource "page" "download_azure" {
  title = "Download From Azure Blob Storage"
  file  = "instructions/04-download-azure.md"

  variables = {
    azure_account   = resource.exec.setup_workstation.output.AZURE_STORAGE_ACCOUNT
    azure_container = resource.exec.setup_workstation.output.AZURE_CONTAINER
  }

  activities = {
    "download_azure" = resource.task.download_azure
  }
}

resource "page" "download_gcp" {
  title = "Download From Google Cloud Storage"
  file  = "instructions/05-download-gcp.md"

  variables = {
    gcp_bucket = resource.exec.setup_workstation.output.GCP_BUCKET
  }

  activities = {
    "download_gcp" = resource.task.download_gcp
  }
}

resource "page" "summary" {
  title = "Summary"
  file  = "instructions/06-summary.md"
}
__MCLAB_EOF__

mkdir -p "."
cat > "sandbox.hcl" <<'__MCLAB_EOF__'
# -----------------------------------------------------------------------------
# Workstation - a single Ubuntu container the learner works in.
# `tail -f /dev/null` keeps the container alive (same pattern as the
# instruqt/lab-examples "demo" lab).
# -----------------------------------------------------------------------------
resource "container" "workstation" {
  image {
    name = "ubuntu:22.04"
  }

  command = ["tail", "-f", "/dev/null"]

  resources {
    cpu    = 2000
    memory = 4096
  }
}

# -----------------------------------------------------------------------------
# Setup script - runs inside the workstation before the learner gets access.
# It installs the AWS CLI v2, Azure CLI and Google Cloud CLI, logs each CLI in,
# creates one storage bucket/container per cloud, creates the file to upload
# and writes /root/.multicloud/env for the terminal and the check scripts.
# -----------------------------------------------------------------------------
resource "exec" "setup_workstation" {
  target  = resource.container.workstation
  script  = "scripts/exec/setup_workstation/script.sh"
  timeout = "1800s"

  environment = {
    # AWS - IAM user "student" (user.0)
    LAB_AWS_ACCESS_KEY_ID     = resource.aws_account.multicloud.user.0.access_key_id
    LAB_AWS_SECRET_ACCESS_KEY = resource.aws_account.multicloud.user.0.secret_access_key
    LAB_AWS_REGION            = resource.aws_account.multicloud.regions.0

    # Azure - service principal "automation" (service_principal.0)
    LAB_AZURE_CLIENT_ID       = resource.azure_subscription.multicloud.service_principal.0.app_id
    LAB_AZURE_CLIENT_SECRET   = resource.azure_subscription.multicloud.service_principal.0.password
    LAB_AZURE_TENANT_ID       = resource.azure_subscription.multicloud.tenant_id
    LAB_AZURE_SUBSCRIPTION_ID = resource.azure_subscription.multicloud.subscription_id
    LAB_AZURE_REGION          = resource.azure_subscription.multicloud.regions.0

    # Google Cloud - service account "automation" (service_account.0)
    LAB_GCP_PROJECT_ID = resource.google_project.multicloud.project_id
    LAB_GCP_SA_KEY     = resource.google_project.multicloud.service_account.0.key
    LAB_GCP_REGION     = resource.google_project.multicloud.regions.0
  }
}
__MCLAB_EOF__

mkdir -p "scripts/exec/setup_workstation"
cat > "scripts/exec/setup_workstation/script.sh" <<'__MCLAB_EOF__'
#!/bin/bash
# =============================================================================
# Multi-cloud workstation setup (exec resource: setup_workstation)
#
# Runs inside the "workstation" container before the learner gets access:
#   1. Installs AWS CLI v2, Azure CLI and Google Cloud CLI
#   2. Signs each CLI in with the lab's cloud credentials
#   3. Creates one bucket / container per cloud (globally unique names)
#   4. Creates the file the learner will upload
#   5. Writes /root/.multicloud/env (sourced by the terminal and check scripts)
#
# Credentials arrive as LAB_* environment variables from sandbox.hcl.
# NOTE: this file deliberately avoids the dollar-brace and percent-brace
# sequences so it is safe even if the platform runs HCL interpolation on it.
# =============================================================================
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LAB_HOME=/root/multicloud-lab
STATE_DIR=/root/.multicloud
ENV_FILE=$STATE_DIR/env
LAB_FILE=hello-multicloud.txt
LOG_FILE=/var/log/multicloud-setup.log

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
touch "$LOG_FILE"

log() {
  echo "[setup $(date -u +%H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

# retry <attempts> <sleep-seconds> <command...>
retry() {
  local attempts=$1
  local delay=$2
  local n=1
  shift 2
  until "$@"; do
    if [ "$n" -ge "$attempts" ]; then
      log "FAILED after $n attempts: $1"
      return 1
    fi
    log "attempt $n/$attempts failed for: $1 - retrying in $delay s"
    n=$((n + 1))
    sleep "$delay"
  done
}

# ---------------------------------------------------------------------------
# 0. Sanity check - every credential must be present
# ---------------------------------------------------------------------------
for v in LAB_AWS_ACCESS_KEY_ID LAB_AWS_SECRET_ACCESS_KEY LAB_AWS_REGION \
         LAB_AZURE_CLIENT_ID LAB_AZURE_CLIENT_SECRET LAB_AZURE_TENANT_ID \
         LAB_AZURE_SUBSCRIPTION_ID LAB_AZURE_REGION \
         LAB_GCP_PROJECT_ID LAB_GCP_SA_KEY LAB_GCP_REGION; do
  if [ -z "$(printenv "$v")" ]; then
    log "ERROR: required environment variable $v is empty"
    exit 1
  fi
done
log "All cloud credentials received"

# ---------------------------------------------------------------------------
# 1. Base packages
# ---------------------------------------------------------------------------
log "Installing base packages"
retry 5 10 apt-get update -y
retry 3 10 apt-get install -y --no-install-recommends \
  ca-certificates curl unzip gnupg lsb-release apt-transport-https \
  python3 jq less nano vim-tiny tree

# ---------------------------------------------------------------------------
# 2. AWS CLI v2
# ---------------------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  log "Installing AWS CLI v2"
  case "$(uname -m)" in
    aarch64|arm64) AWS_ARCH=aarch64 ;;
    *)             AWS_ARCH=x86_64 ;;
  esac
  retry 5 10 curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$AWS_ARCH.zip" -o /tmp/awscliv2.zip
  rm -rf /tmp/aws
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
  rm -rf /tmp/aws /tmp/awscliv2.zip
fi
log "$(aws --version 2>&1)"

# ---------------------------------------------------------------------------
# 3. Azure CLI (official Microsoft install script for Debian/Ubuntu)
# ---------------------------------------------------------------------------
if ! command -v az >/dev/null 2>&1; then
  log "Installing Azure CLI"
  retry 5 10 curl -fsSL https://aka.ms/InstallAzureCLIDeb -o /tmp/install-az.sh
  retry 3 15 bash /tmp/install-az.sh
  rm -f /tmp/install-az.sh
fi
az config set core.collect_telemetry=false --only-show-errors >/dev/null 2>&1 || true
az config set core.login_experience_v2=off --only-show-errors >/dev/null 2>&1 || true
log "$(az version --query '"azure-cli"' -o tsv 2>/dev/null | sed 's/^/azure-cli /')"

# ---------------------------------------------------------------------------
# 4. Google Cloud CLI (official apt repository)
# ---------------------------------------------------------------------------
if ! command -v gcloud >/dev/null 2>&1; then
  log "Installing Google Cloud CLI"
  retry 5 10 curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o /tmp/cloud.google.asc
  gpg --batch --yes --dearmor -o /usr/share/keyrings/cloud.google.gpg /tmp/cloud.google.asc
  rm -f /tmp/cloud.google.asc
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list
  retry 5 10 apt-get update -y
  retry 3 10 apt-get install -y --no-install-recommends google-cloud-cli
fi
log "$(gcloud --version 2>/dev/null | head -n 1)"

# ---------------------------------------------------------------------------
# 5. Unique suffix for globally unique bucket names (kept stable on re-run)
# ---------------------------------------------------------------------------
if [ -s "$STATE_DIR/suffix" ]; then
  SUFFIX=$(cat "$STATE_DIR/suffix")
else
  SUFFIX=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | cut -c1-10)
  echo "$SUFFIX" > "$STATE_DIR/suffix"
fi

AWS_BUCKET="mc-lab-aws-$SUFFIX"
AZURE_RESOURCE_GROUP="multicloud-lab-rg"
AZURE_STORAGE_ACCOUNT="mclab$SUFFIX"          # 3-24 lowercase letters/digits
AZURE_CONTAINER="multicloud-lab"
GCP_BUCKET="mc-lab-gcp-$SUFFIX"
log "Suffix: $SUFFIX"

# ---------------------------------------------------------------------------
# 6. AWS - configure CLI and create the S3 bucket
# ---------------------------------------------------------------------------
log "Configuring AWS CLI"
mkdir -p /root/.aws
cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = $LAB_AWS_ACCESS_KEY_ID
aws_secret_access_key = $LAB_AWS_SECRET_ACCESS_KEY
EOF
cat > /root/.aws/config <<EOF
[default]
region = $LAB_AWS_REGION
output = json
EOF
chmod 600 /root/.aws/credentials /root/.aws/config

# New IAM access keys can take a little while to become active.
retry 30 10 aws s3api list-buckets --query 'Buckets[0].Name' --output text >/dev/null

aws_create_bucket() {
  if aws s3api head-bucket --bucket "$AWS_BUCKET" >/dev/null 2>&1; then
    return 0
  fi
  if [ "$LAB_AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$AWS_BUCKET" >/dev/null
  else
    aws s3api create-bucket --bucket "$AWS_BUCKET" \
      --create-bucket-configuration "LocationConstraint=$LAB_AWS_REGION" >/dev/null
  fi
}
log "Creating S3 bucket s3://$AWS_BUCKET"
retry 12 10 aws_create_bucket
retry 12 5 aws s3api head-bucket --bucket "$AWS_BUCKET"

# ---------------------------------------------------------------------------
# 7. Azure - sign in, create resource group, storage account and container
# ---------------------------------------------------------------------------
azure_login() {
  # --client-secret is the current flag; --password is the older one.
  az login --service-principal \
      --username "$LAB_AZURE_CLIENT_ID" \
      --client-secret="$LAB_AZURE_CLIENT_SECRET" \
      --tenant "$LAB_AZURE_TENANT_ID" --output none --only-show-errors 2>/dev/null \
  || az login --service-principal \
      --username "$LAB_AZURE_CLIENT_ID" \
      --password="$LAB_AZURE_CLIENT_SECRET" \
      --tenant "$LAB_AZURE_TENANT_ID" --output none --only-show-errors
}
log "Signing in to Azure"
# New service principals can take a few minutes to replicate in Entra ID.
retry 30 10 azure_login
retry 10 10 az account set --subscription "$LAB_AZURE_SUBSCRIPTION_ID"

log "Registering Microsoft.Storage resource provider (if needed)"
timeout 300 az provider register --namespace Microsoft.Storage --wait --only-show-errors >/dev/null 2>&1 || \
  log "Provider registration skipped (already registered or not permitted)"

log "Creating resource group $AZURE_RESOURCE_GROUP in $LAB_AZURE_REGION"
retry 20 15 az group create --name "$AZURE_RESOURCE_GROUP" --location "$LAB_AZURE_REGION" \
  --output none --only-show-errors

azure_create_storage_account() {
  if az storage account show --name "$AZURE_STORAGE_ACCOUNT" \
       --resource-group "$AZURE_RESOURCE_GROUP" --output none --only-show-errors 2>/dev/null; then
    return 0
  fi
  az storage account create \
    --name "$AZURE_STORAGE_ACCOUNT" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --location "$LAB_AZURE_REGION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output none --only-show-errors
}
log "Creating storage account $AZURE_STORAGE_ACCOUNT"
retry 12 20 azure_create_storage_account

AZURE_STORAGE_KEY=""
azure_get_key() {
  AZURE_STORAGE_KEY=$(az storage account keys list \
    --account-name "$AZURE_STORAGE_ACCOUNT" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query '[0].value' --output tsv --only-show-errors)
  [ -n "$AZURE_STORAGE_KEY" ]
}
retry 12 10 azure_get_key

log "Creating blob container $AZURE_CONTAINER"
retry 12 10 az storage container create \
  --name "$AZURE_CONTAINER" \
  --account-name "$AZURE_STORAGE_ACCOUNT" \
  --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --output none --only-show-errors

# ---------------------------------------------------------------------------
# 8. Google Cloud - activate the service account and create the GCS bucket
# ---------------------------------------------------------------------------
log "Configuring Google Cloud CLI"
GCP_KEY_FILE=$STATE_DIR/gcp-key.json
printf '%s' "$LAB_GCP_SA_KEY" > "$GCP_KEY_FILE"
# The key should be JSON; fall back to base64 decoding just in case.
if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$GCP_KEY_FILE" 2>/dev/null; then
  printf '%s' "$LAB_GCP_SA_KEY" | base64 -d > "$GCP_KEY_FILE"
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$GCP_KEY_FILE"
fi
chmod 600 "$GCP_KEY_FILE"

gcloud config set core/disable_usage_reporting true --quiet >/dev/null 2>&1 || true
gcloud config set survey/disable_prompts true --quiet >/dev/null 2>&1 || true
retry 10 10 gcloud auth activate-service-account --key-file="$GCP_KEY_FILE" --quiet
gcloud config set project "$LAB_GCP_PROJECT_ID" --quiet >/dev/null 2>&1

gcp_create_bucket() {
  if gcloud storage buckets describe "gs://$GCP_BUCKET" --format='value(name)' >/dev/null 2>&1; then
    return 0
  fi
  gcloud storage buckets create "gs://$GCP_BUCKET" \
    --project="$LAB_GCP_PROJECT_ID" \
    --location="$LAB_GCP_REGION" \
    --uniform-bucket-level-access --quiet
}
log "Creating GCS bucket gs://$GCP_BUCKET"
# The Storage API and IAM bindings can take a moment on a fresh project.
retry 20 15 gcp_create_bucket

# ---------------------------------------------------------------------------
# 9. Working folders and the file to upload
# ---------------------------------------------------------------------------
log "Creating lab folders"
mkdir -p "$LAB_HOME/upload" \
         "$LAB_HOME/downloads/aws" \
         "$LAB_HOME/downloads/azure" \
         "$LAB_HOME/downloads/gcp"

if [ ! -s "$LAB_HOME/upload/$LAB_FILE" ]; then
  cat > "$LAB_HOME/upload/$LAB_FILE" <<EOF
Hello from the Instruqt multi-cloud storage lab!

This file was pushed from one terminal to three clouds:
  - AWS S3                 s3://$AWS_BUCKET
  - Azure Blob Storage     $AZURE_STORAGE_ACCOUNT/$AZURE_CONTAINER
  - Google Cloud Storage   gs://$GCP_BUCKET

Created (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')
Lab ID: $SUFFIX
EOF
fi

# ---------------------------------------------------------------------------
# 10. Environment file for the terminal and the check scripts
# ---------------------------------------------------------------------------
cat > "$ENV_FILE" <<EOF
# Generated by the multi-cloud lab setup - do not edit
export LAB_HOME="$LAB_HOME"
export LAB_FILE="$LAB_FILE"
export UPLOAD_FILE="$LAB_HOME/upload/$LAB_FILE"

export AWS_BUCKET="$AWS_BUCKET"
export AWS_DEFAULT_REGION="$LAB_AWS_REGION"

export AZURE_SUBSCRIPTION_ID="$LAB_AZURE_SUBSCRIPTION_ID"
export AZURE_RESOURCE_GROUP="$AZURE_RESOURCE_GROUP"
export AZURE_STORAGE_ACCOUNT="$AZURE_STORAGE_ACCOUNT"
export AZURE_STORAGE_KEY="$AZURE_STORAGE_KEY"
export AZURE_CONTAINER="$AZURE_CONTAINER"

export GCP_PROJECT="$LAB_GCP_PROJECT_ID"
export GCP_BUCKET="$GCP_BUCKET"
EOF
chmod 600 "$ENV_FILE"

if ! grep -q 'multicloud/env' /root/.bashrc 2>/dev/null; then
  cat >> /root/.bashrc <<'EOF'

# --- Multi-cloud storage lab ---
[ -f /root/.multicloud/env ] && . /root/.multicloud/env
export PATH=/usr/local/bin:$PATH
cd /root/multicloud-lab 2>/dev/null || true
EOF
fi

# Small helper so learners can always see their bucket names
cat > /usr/local/bin/lab-info <<'EOF'
#!/bin/bash
. /root/.multicloud/env
echo ""
echo "  Multi-cloud storage lab"
echo "  -----------------------"
echo "  File to upload : $UPLOAD_FILE"
echo "  AWS S3         : s3://$AWS_BUCKET   (region $AWS_DEFAULT_REGION)"
echo "  Azure Blob     : account $AZURE_STORAGE_ACCOUNT, container $AZURE_CONTAINER"
echo "  Google Cloud   : gs://$GCP_BUCKET   (project $GCP_PROJECT)"
echo "  Downloads to   : $LAB_HOME/downloads/{aws,azure,gcp}/"
echo ""
EOF
chmod +x /usr/local/bin/lab-info

# ---------------------------------------------------------------------------
# 11. Outputs for the instructions (page variables)
# ---------------------------------------------------------------------------
if [ -n "$EXEC_OUTPUT" ]; then
  {
    echo "AWS_BUCKET=$AWS_BUCKET"
    echo "AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT"
    echo "AZURE_CONTAINER=$AZURE_CONTAINER"
    echo "GCP_BUCKET=$GCP_BUCKET"
  } >> "$EXEC_OUTPUT"
fi

log "Setup complete"
__MCLAB_EOF__

mkdir -p "scripts/task/download_aws"
cat > "scripts/task/download_aws/check.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that the learner downloaded hello-multicloud.txt from AWS S3 into
# ~/multicloud-lab/downloads/aws/ and that it arrived intact: its SHA-256 must
# match the original upload file AND the object currently stored in AWS S3.
DOWNLOADED="$LAB_HOME/downloads/aws/$LAB_FILE"
if [ ! -f "$DOWNLOADED" ]; then
  echo "$DOWNLOADED not found. Download it with: aws s3 cp s3://$AWS_BUCKET/$LAB_FILE $LAB_HOME/downloads/aws/"
  exit 1
fi
if [ ! -s "$DOWNLOADED" ]; then
  echo "$DOWNLOADED is empty - the download did not complete."
  exit 1
fi
ORIGINAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
RECEIVED=$(sha256sum "$DOWNLOADED" | cut -d' ' -f1)
if [ "$ORIGINAL" != "$RECEIVED" ]; then
  echo "Checksum mismatch: original $ORIGINAL, received $RECEIVED."
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if ! aws s3 cp "s3://$AWS_BUCKET/$LAB_FILE" "$TMP/object" --only-show-errors; then
  echo "Could not read s3://$AWS_BUCKET/$LAB_FILE - complete the upload step first."
  exit 1
fi
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$CLOUD" != "$RECEIVED" ]; then
  echo "Your downloaded file does not match the object stored in AWS S3."
  exit 1
fi
echo "Received from AWS S3 successfully (sha256 $RECEIVED)"
__MCLAB_EOF__

mkdir -p "scripts/task/download_aws"
cat > "scripts/task/download_aws/solve.sh" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "scripts/task/download_azure"
cat > "scripts/task/download_azure/check.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that the learner downloaded hello-multicloud.txt from Azure Blob Storage into
# ~/multicloud-lab/downloads/azure/ and that it arrived intact: its SHA-256 must
# match the original upload file AND the object currently stored in Azure Blob Storage.
DOWNLOADED="$LAB_HOME/downloads/azure/$LAB_FILE"
if [ ! -f "$DOWNLOADED" ]; then
  echo "$DOWNLOADED not found. Download it with az storage blob download (see the instructions)."
  exit 1
fi
if [ ! -s "$DOWNLOADED" ]; then
  echo "$DOWNLOADED is empty - the download did not complete."
  exit 1
fi
ORIGINAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
RECEIVED=$(sha256sum "$DOWNLOADED" | cut -d' ' -f1)
if [ "$ORIGINAL" != "$RECEIVED" ]; then
  echo "Checksum mismatch: original $ORIGINAL, received $RECEIVED."
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if ! az storage blob download --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --file "$TMP/object" --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --no-progress --output none --only-show-errors; then
  echo "Could not read blob $LAB_FILE from container $AZURE_CONTAINER - complete the upload step first."
  exit 1
fi
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$CLOUD" != "$RECEIVED" ]; then
  echo "Your downloaded file does not match the object stored in Azure Blob Storage."
  exit 1
fi
echo "Received from Azure Blob Storage successfully (sha256 $RECEIVED)"
__MCLAB_EOF__

mkdir -p "scripts/task/download_azure"
cat > "scripts/task/download_azure/solve.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

set -e
mkdir -p "$LAB_HOME/downloads/azure"
AZ_AUTH="--account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_KEY --auth-mode key --only-show-errors"
EXISTS=$(az storage blob exists --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" $AZ_AUTH --query exists -o tsv 2>/dev/null || true)
if [ "$EXISTS" != "true" ]; then
  az storage blob upload --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
    --file "$UPLOAD_FILE" $AZ_AUTH --overwrite --no-progress --output none
fi
az storage blob download --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --file "$LAB_HOME/downloads/azure/$LAB_FILE" $AZ_AUTH --no-progress --output none
__MCLAB_EOF__

mkdir -p "scripts/task/download_gcp"
cat > "scripts/task/download_gcp/check.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that the learner downloaded hello-multicloud.txt from Google Cloud Storage into
# ~/multicloud-lab/downloads/gcp/ and that it arrived intact: its SHA-256 must
# match the original upload file AND the object currently stored in Google Cloud Storage.
DOWNLOADED="$LAB_HOME/downloads/gcp/$LAB_FILE"
if [ ! -f "$DOWNLOADED" ]; then
  echo "$DOWNLOADED not found. Download it with: gcloud storage cp gs://$GCP_BUCKET/$LAB_FILE $LAB_HOME/downloads/gcp/"
  exit 1
fi
if [ ! -s "$DOWNLOADED" ]; then
  echo "$DOWNLOADED is empty - the download did not complete."
  exit 1
fi
ORIGINAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
RECEIVED=$(sha256sum "$DOWNLOADED" | cut -d' ' -f1)
if [ "$ORIGINAL" != "$RECEIVED" ]; then
  echo "Checksum mismatch: original $ORIGINAL, received $RECEIVED."
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if ! gcloud storage cp "gs://$GCP_BUCKET/$LAB_FILE" "$TMP/object" --quiet >/dev/null 2>&1; then
  echo "Could not read gs://$GCP_BUCKET/$LAB_FILE - complete the upload step first."
  exit 1
fi
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$CLOUD" != "$RECEIVED" ]; then
  echo "Your downloaded file does not match the object stored in Google Cloud Storage."
  exit 1
fi
echo "Received from Google Cloud Storage successfully (sha256 $RECEIVED)"
__MCLAB_EOF__

mkdir -p "scripts/task/download_gcp"
cat > "scripts/task/download_gcp/solve.sh" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "scripts/task/upload_file"
cat > "scripts/task/upload_file/check_aws.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that hello-multicloud.txt is in the S3 bucket and is byte-identical
# to the learner's local file (the object is fetched and SHA-256 compared).
if [ ! -s "$UPLOAD_FILE" ]; then
  echo "Local file $UPLOAD_FILE is missing or empty."
  exit 1
fi
if ! aws s3api head-object --bucket "$AWS_BUCKET" --key "$LAB_FILE" >/dev/null 2>&1; then
  echo "s3://$AWS_BUCKET/$LAB_FILE was not found. Upload it with: aws s3 cp $UPLOAD_FILE s3://$AWS_BUCKET/"
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
aws s3 cp "s3://$AWS_BUCKET/$LAB_FILE" "$TMP/object" --only-show-errors || exit 1
LOCAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$LOCAL" != "$CLOUD" ]; then
  echo "The S3 object does not match your local file (local $LOCAL, s3 $CLOUD). Upload it again."
  exit 1
fi
echo "AWS upload verified (sha256 $CLOUD)"
__MCLAB_EOF__

mkdir -p "scripts/task/upload_file"
cat > "scripts/task/upload_file/check_azure.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that hello-multicloud.txt is in the Azure Blob container and is
# byte-identical to the learner's local file.
if [ ! -s "$UPLOAD_FILE" ]; then
  echo "Local file $UPLOAD_FILE is missing or empty."
  exit 1
fi
EXISTS=$(az storage blob exists --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --query exists -o tsv --only-show-errors 2>/dev/null)
if [ "$EXISTS" != "true" ]; then
  echo "Blob $LAB_FILE was not found in container $AZURE_CONTAINER."
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
az storage blob download --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --file "$TMP/object" --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --no-progress --output none --only-show-errors || exit 1
LOCAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$LOCAL" != "$CLOUD" ]; then
  echo "The Azure blob does not match your local file (local $LOCAL, blob $CLOUD). Upload it again with --overwrite."
  exit 1
fi
echo "Azure upload verified (sha256 $CLOUD)"
__MCLAB_EOF__

mkdir -p "scripts/task/upload_file"
cat > "scripts/task/upload_file/check_gcp.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Checks that hello-multicloud.txt is in the GCS bucket and is byte-identical
# to the learner's local file.
if [ ! -s "$UPLOAD_FILE" ]; then
  echo "Local file $UPLOAD_FILE is missing or empty."
  exit 1
fi
if ! gcloud storage objects describe "gs://$GCP_BUCKET/$LAB_FILE" --format='value(name)' >/dev/null 2>&1; then
  echo "gs://$GCP_BUCKET/$LAB_FILE was not found. Upload it with: gcloud storage cp $UPLOAD_FILE gs://$GCP_BUCKET/"
  exit 1
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
gcloud storage cp "gs://$GCP_BUCKET/$LAB_FILE" "$TMP/object" --quiet >/dev/null 2>&1 || exit 1
LOCAL=$(sha256sum "$UPLOAD_FILE" | cut -d' ' -f1)
CLOUD=$(sha256sum "$TMP/object" | cut -d' ' -f1)
if [ "$LOCAL" != "$CLOUD" ]; then
  echo "The GCS object does not match your local file (local $LOCAL, gcs $CLOUD). Upload it again."
  exit 1
fi
echo "GCP upload verified (sha256 $CLOUD)"
__MCLAB_EOF__

mkdir -p "scripts/task/upload_file"
cat > "scripts/task/upload_file/solve_aws.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

set -e
aws s3 cp "$UPLOAD_FILE" "s3://$AWS_BUCKET/$LAB_FILE" --only-show-errors
__MCLAB_EOF__

mkdir -p "scripts/task/upload_file"
cat > "scripts/task/upload_file/solve_azure.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

set -e
az storage blob upload --container-name "$AZURE_CONTAINER" --name "$LAB_FILE" \
  --file "$UPLOAD_FILE" --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --overwrite --no-progress --output none --only-show-errors
__MCLAB_EOF__

mkdir -p "scripts/task/upload_file"
cat > "scripts/task/upload_file/solve_gcp.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

set -e
gcloud storage cp "$UPLOAD_FILE" "gs://$GCP_BUCKET/$LAB_FILE" --quiet
__MCLAB_EOF__

mkdir -p "scripts/task/verify_environment"
cat > "scripts/task/verify_environment/check_aws.sh" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "scripts/task/verify_environment"
cat > "scripts/task/verify_environment/check_azure.sh" <<'__MCLAB_EOF__'
#!/bin/bash
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ ! -f /root/.multicloud/env ]; then
  echo "Lab environment file /root/.multicloud/env not found - the setup script did not finish."
  exit 1
fi
. /root/.multicloud/env

# Azure CLI signed in to the lab subscription and the blob container exists
if ! az account show --query id -o tsv --only-show-errors 2>/dev/null | grep -q "$AZURE_SUBSCRIPTION_ID"; then
  echo "Azure CLI is not signed in to subscription $AZURE_SUBSCRIPTION_ID."
  exit 1
fi
EXISTS=$(az storage container exists --name "$AZURE_CONTAINER" \
  --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" \
  --auth-mode key --query exists -o tsv --only-show-errors 2>/dev/null)
if [ "$EXISTS" != "true" ]; then
  echo "Blob container $AZURE_CONTAINER was not found in storage account $AZURE_STORAGE_ACCOUNT."
  exit 1
fi
echo "Azure OK: $AZURE_STORAGE_ACCOUNT/$AZURE_CONTAINER"
__MCLAB_EOF__

mkdir -p "scripts/task/verify_environment"
cat > "scripts/task/verify_environment/check_gcp.sh" <<'__MCLAB_EOF__'
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
__MCLAB_EOF__

mkdir -p "."
cat > "tabs.hcl" <<'__MCLAB_EOF__'
# Terminal on the workstation - all three CLIs are ready to use here.
resource "terminal" "workstation" {
  target            = resource.container.workstation
  shell             = "/bin/bash"
  working_directory = "/root"
}

# One tab with the console credentials for all three clouds.
resource "cloud_credentials" "multicloud" {
  aws_account {
    target = resource.aws_account.multicloud
    users  = ["student"]
  }

  azure_subscription {
    target             = resource.azure_subscription.multicloud
    users              = ["student"]
    service_principals = ["automation"]
  }

  google_project {
    target           = resource.google_project.multicloud
    users            = ["student"]
    service_accounts = ["automation"]
  }
}
__MCLAB_EOF__

mkdir -p "."
cat > "tasks.hcl" <<'__MCLAB_EOF__'
# All check / solve scripts run inside the workstation container as root.
# The Azure CLI is slow to start, so the default 30s timeout is raised to 120s.

# -----------------------------------------------------------------------------
# Page 1 - confirm the setup script provisioned everything
# -----------------------------------------------------------------------------
resource "task" "verify_environment" {
  description     = "Confirm all three CLIs are signed in and every bucket exists"
  success_message = "All three clouds are ready. Time to push some data!"

  config {
    target  = resource.container.workstation
    timeout = "120s"
  }

  condition "aws_ready" {
    description = "AWS CLI is signed in and the S3 bucket exists"

    check {
      script          = "scripts/task/verify_environment/check_aws.sh"
      failure_message = "The AWS CLI or the S3 bucket is not ready. Run `lab-info` and check /var/log/multicloud-setup.log."
    }
  }

  condition "azure_ready" {
    description = "Azure CLI is signed in and the Blob container exists"

    check {
      script          = "scripts/task/verify_environment/check_azure.sh"
      failure_message = "The Azure CLI or the Blob container is not ready. Run `lab-info` and check /var/log/multicloud-setup.log."
    }
  }

  condition "gcp_ready" {
    description = "Google Cloud CLI is signed in and the GCS bucket exists"

    check {
      script          = "scripts/task/verify_environment/check_gcp.sh"
      failure_message = "The Google Cloud CLI or the GCS bucket is not ready. Run `lab-info` and check /var/log/multicloud-setup.log."
    }
  }
}

# -----------------------------------------------------------------------------
# Page 2 - push the same file to all three clouds
# -----------------------------------------------------------------------------
resource "task" "upload_file" {
  description     = "Upload hello-multicloud.txt to AWS S3, Azure Blob Storage and Google Cloud Storage"
  success_message = "The file is stored in all three clouds and matches your local copy."

  config {
    target  = resource.container.workstation
    timeout = "120s"
  }

  condition "uploaded_to_aws" {
    description = "hello-multicloud.txt is in the S3 bucket and matches the local file"

    check {
      script          = "scripts/task/upload_file/check_aws.sh"
      failure_message = "hello-multicloud.txt is missing from the S3 bucket or does not match ~/multicloud-lab/upload/hello-multicloud.txt."
    }

    solve {
      script = "scripts/task/upload_file/solve_aws.sh"
    }
  }

  condition "uploaded_to_azure" {
    description = "hello-multicloud.txt is in the Azure Blob container and matches the local file"

    check {
      script          = "scripts/task/upload_file/check_azure.sh"
      failure_message = "hello-multicloud.txt is missing from the Azure Blob container or does not match ~/multicloud-lab/upload/hello-multicloud.txt."
    }

    solve {
      script = "scripts/task/upload_file/solve_azure.sh"
    }
  }

  condition "uploaded_to_gcp" {
    description = "hello-multicloud.txt is in the GCS bucket and matches the local file"

    check {
      script          = "scripts/task/upload_file/check_gcp.sh"
      failure_message = "hello-multicloud.txt is missing from the GCS bucket or does not match ~/multicloud-lab/upload/hello-multicloud.txt."
    }

    solve {
      script = "scripts/task/upload_file/solve_gcp.sh"
    }
  }
}

# -----------------------------------------------------------------------------
# Pages 3-5 - pull the file back from each cloud separately
# -----------------------------------------------------------------------------
resource "task" "download_aws" {
  description     = "Download hello-multicloud.txt from S3 into ~/multicloud-lab/downloads/aws/"
  success_message = "Received from AWS S3 - checksum matches the original."

  config {
    target  = resource.container.workstation
    timeout = "120s"
  }

  condition "received_from_aws" {
    description = "~/multicloud-lab/downloads/aws/hello-multicloud.txt exists and its SHA-256 matches the original and the S3 object"

    check {
      script          = "scripts/task/download_aws/check.sh"
      failure_message = "~/multicloud-lab/downloads/aws/hello-multicloud.txt is missing or its checksum does not match the original."
    }

    solve {
      script = "scripts/task/download_aws/solve.sh"
    }
  }
}

resource "task" "download_azure" {
  description     = "Download hello-multicloud.txt from Azure Blob Storage into ~/multicloud-lab/downloads/azure/"
  success_message = "Received from Azure Blob Storage - checksum matches the original."

  config {
    target  = resource.container.workstation
    timeout = "120s"
  }

  condition "received_from_azure" {
    description = "~/multicloud-lab/downloads/azure/hello-multicloud.txt exists and its SHA-256 matches the original and the blob"

    check {
      script          = "scripts/task/download_azure/check.sh"
      failure_message = "~/multicloud-lab/downloads/azure/hello-multicloud.txt is missing or its checksum does not match the original."
    }

    solve {
      script = "scripts/task/download_azure/solve.sh"
    }
  }
}

resource "task" "download_gcp" {
  description     = "Download hello-multicloud.txt from Google Cloud Storage into ~/multicloud-lab/downloads/gcp/"
  success_message = "Received from Google Cloud Storage - checksum matches the original."

  config {
    target  = resource.container.workstation
    timeout = "120s"
  }

  condition "received_from_gcp" {
    description = "~/multicloud-lab/downloads/gcp/hello-multicloud.txt exists and its SHA-256 matches the original and the GCS object"

    check {
      script          = "scripts/task/download_gcp/check.sh"
      failure_message = "~/multicloud-lab/downloads/gcp/hello-multicloud.txt is missing or its checksum does not match the original."
    }

    solve {
      script = "scripts/task/download_gcp/solve.sh"
    }
  }
}
__MCLAB_EOF__

find scripts -name '*.sh' -exec chmod +x {} +
echo "Restored lab to $(pwd)"
find . -type f | sort
