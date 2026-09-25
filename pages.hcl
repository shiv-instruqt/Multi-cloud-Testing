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
