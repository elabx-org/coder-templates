terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {}
provider "coder" {}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

variable "docker_image" {
  description = "Workspace Docker image"
  default     = "ghcr.io/elabx-org/coder-workspace-dev:latest"
}

data "coder_parameter" "instance_size" {
  name         = "instance_size"
  display_name = "Instance Size"
  description  = "CPU and memory allocated to the workspace"
  default      = "medium"
  mutable      = false

  option {
    name  = "Small (2 CPU, 2GB RAM)"
    value = "small"
  }
  option {
    name  = "Medium (4 CPU, 4GB RAM)"
    value = "medium"
  }
  option {
    name  = "Large (8 CPU, 8GB RAM)"
    value = "large"
  }
}

locals {
  cpu_shares = {
    small  = 512
    medium = 1024
    large  = 2048
  }
  memory_mb = {
    small  = 2048
    medium = 4096
    large  = 8192
  }
}

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  startup_script = <<-EOT
    set -e

    # Install code-server if not present
    if [ ! -f /tmp/code-server/bin/code-server ]; then
      curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
    fi

    # Install VS Code extensions
    /tmp/code-server/bin/code-server --install-extension golang.go --force
    /tmp/code-server/bin/code-server --install-extension mathiasfrohlich.Kotlin --force
    /tmp/code-server/bin/code-server --install-extension vscjava.vscode-java-pack --force

    # Start code-server
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT

  env = {
    JAVA_HOME = "/usr/lib/jvm/java-21-openjdk-amd64"
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-home"
}

resource "docker_image" "workspace" {
  name         = var.docker_image
  keep_locally = true
}

resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.workspace.image_id
  name     = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  hostname = data.coder_workspace.me.name

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]

  command = ["sh", "-c", coder_agent.main.init_script]

  cpu_shares = local.cpu_shares[data.coder_parameter.instance_size.value]
  memory     = local.memory_mb[data.coder_parameter.instance_size.value]

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
}
