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
