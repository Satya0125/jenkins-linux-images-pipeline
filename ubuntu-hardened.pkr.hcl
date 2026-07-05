packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "source_ami_name_filter" {
  type    = string
  default = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "image_name" {
  type    = string
  default = "ubuntu-22-hardened"
}

variable "build_number" {
  type    = string
  default = "local"
}

variable "git_commit" {
  type    = string
  default = "unknown"
}

source "amazon-ebs" "ubuntu" {
  region        = var.aws_region
  instance_type = var.instance_type
  ssh_username  = "ubuntu"

  source_ami_filter {
    filters = {
      name                = var.source_ami_name_filter
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  ami_name = "${var.image_name}-${var.build_number}"

  tags = {
    Name          = "${var.image_name}"
    Build         = var.build_number
    GitCommit     = var.git_commit
    HardenedImage = "true"
    OS            = "Ubuntu-22.04"
  }
}

build {
  name    = "ubuntu-hardened"
  sources = ["source.amazon-ebs.ubuntu"]

  # Wait for cloud-init to finish before touching the system
  provisioner "shell" {
    inline = ["cloud-init status --wait || true"]
  }

  # Apply CIS hardening
  provisioner "shell" {
    script          = "scripts/cis_harden.sh"
    execute_command = "chmod +x {{ .Path }}; sudo -E {{ .Path }}"
  }

  # Run compliance validation and write a report the pipeline can read
  provisioner "shell" {
    script          = "scripts/validate.sh"
    execute_command = "chmod +x {{ .Path }}; sudo -E {{ .Path }}"
  }

  # Clean up before baking the final image
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /tmp/* /var/tmp/*",
      "history -c"
    ]
  }
}
