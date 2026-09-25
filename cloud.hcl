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

# TEMPORARILY DISABLED (Azure): lab start fails in platform step UpsertAzureTag
# (PredefinedTagNameNotFound on team_id/participant_id/track_id). Re-enable by
# uncommenting the '# ' lines marked below once engineering has fixed it.
# Azure - Contributor lets the setup create the resource group, the storage
# account and read the account key used for blob upload/download.
# resource "azure_subscription" "multicloud" {
  # regions  = ["eastus"]
  # services = ["Microsoft.Storage"]

  # tags = {
    # Purpose = "multicloud-storage-lab"
  # }

  # user "student" {
    # roles = ["Contributor"]
  # }

  # service_principal "automation" {
    # roles = ["Contributor"]
  # }
# }

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
