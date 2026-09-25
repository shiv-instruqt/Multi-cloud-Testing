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
