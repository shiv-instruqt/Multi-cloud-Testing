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
# Azure is optional: it is skipped when LAB_AZURE_CLIENT_ID is not provided
# (Azure is TEMPORARILY DISABLED in cloud.hcl / sandbox.hcl).
if [ -n "$LAB_AZURE_CLIENT_ID" ]; then
  AZURE_ENABLED=true
  AZURE_VARS="LAB_AZURE_CLIENT_ID LAB_AZURE_CLIENT_SECRET LAB_AZURE_TENANT_ID LAB_AZURE_SUBSCRIPTION_ID LAB_AZURE_REGION"
else
  AZURE_ENABLED=false
  AZURE_VARS=""
fi
for v in LAB_AWS_ACCESS_KEY_ID LAB_AWS_SECRET_ACCESS_KEY LAB_AWS_REGION \
         $AZURE_VARS \
         LAB_GCP_PROJECT_ID LAB_GCP_SA_KEY LAB_GCP_REGION; do
  if [ -z "$(printenv "$v")" ]; then
    log "ERROR: required environment variable $v is empty"
    exit 1
  fi
done
log "All cloud credentials received (Azure enabled: $AZURE_ENABLED)"

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
if [ "$AZURE_ENABLED" = "true" ]; then
if ! command -v az >/dev/null 2>&1; then
  log "Installing Azure CLI"
  retry 5 10 curl -fsSL https://aka.ms/InstallAzureCLIDeb -o /tmp/install-az.sh
  retry 3 15 bash /tmp/install-az.sh
  rm -f /tmp/install-az.sh
fi
az config set core.collect_telemetry=false --only-show-errors >/dev/null 2>&1 || true
az config set core.login_experience_v2=off --only-show-errors >/dev/null 2>&1 || true
log "$(az version --query '"azure-cli"' -o tsv 2>/dev/null | sed 's/^/azure-cli /')"
fi

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
AZURE_STORAGE_KEY=""
if [ "$AZURE_ENABLED" = "true" ]; then
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
else
  log "Azure disabled - skipping Azure sign-in and storage"
  AZURE_STORAGE_ACCOUNT="disabled"
  AZURE_CONTAINER="disabled"
fi

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
