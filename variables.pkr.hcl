# Override any of these at build time with:
#   packer build -var="build_number=142" -var="git_commit=a1c9f3e" packer/ubuntu-hardened.pkr.hcl
#
# Or use a .pkrvars.hcl file:
#   packer build -var-file="prod.pkrvars.hcl" packer/ubuntu-hardened.pkr.hcl

# aws_region        = "us-east-1"
# instance_type     = "t3.medium"
# image_name        = "ubuntu-22-hardened"
