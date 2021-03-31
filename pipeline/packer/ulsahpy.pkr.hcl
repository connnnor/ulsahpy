variable "timestamp" {
  type    = string
  default = "{{isotime \"2006-01-02 03:04:05\"}}"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

variable "region" {
  type    = string
  default = "us-east-1"
}

source "amazon-ebs" "ulsahpy-AWS" {
  ami_name      = "ulsahpy-${local.timestamp}"
  instance_type = "t2.micro"
  region        = "${var.region}"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username  = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.ulsahpy-AWS"]

  provisioner "file" {
    destination = "/tmp"
    source      = "ulsahpy"
  }

  provisioner "file" {
    destination = "/tmp/requirements.txt"
    source      = "requirements.txt"
  }

  provisioner "file" {
    destination = "/tmp/ulsahpy.service"
    source      = "pipeline/packer/ulsahpy.service"
  }

  # wait for cloud-init to complete before running apt-get
  provisioner "shell" {
    inline = ["/usr/bin/cloud-init status --wait"]
  }

  provisioner "shell" {
    script = "pipeline/packer/provisioner.sh"
  }
}
