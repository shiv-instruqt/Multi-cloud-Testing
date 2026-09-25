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
