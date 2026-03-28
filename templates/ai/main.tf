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
  default     = "ghcr.io/elabx-org/coder-workspace-ai:latest"
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

    # Run Agent-OS initial setup if first start
    if [ ! -d /home/coder/.agent-os ]; then
      agent-os install 2>/dev/null || true
    fi

    # Start Agent-OS — mobile-first web UI for Claude Code sessions
    export AGENT_OS_PORT=3011
    export AGENT_OS_HOME=/home/coder/.agent-os
    export SHELL=/bin/bash
    agent-os start-foreground >/tmp/agent-os.log 2>&1 &

    # Start ttyd — web terminal for direct Claude Code CLI access
    ttyd -p 7681 -W bash >/tmp/ttyd.log 2>&1 &
  EOT
}

resource "coder_app" "agent-os" {
  agent_id     = coder_agent.main.id
  slug         = "agent-os"
  display_name = "Agent-OS"
  url          = "http://localhost:3011"
  icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/png/anthropic.png"
  subdomain    = false
  share        = "owner"
}

resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  url          = "http://localhost:7681"
  icon         = "/icon/terminal.svg"
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
