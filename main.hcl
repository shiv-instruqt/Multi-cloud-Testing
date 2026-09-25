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
      title = "Push the File to AWS and Google Cloud"

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

      # page "download_azure" {
        # title     = "Download From Azure Blob Storage"
        # reference = resource.page.download_azure
      # }

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
