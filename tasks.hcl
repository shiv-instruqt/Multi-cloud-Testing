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
