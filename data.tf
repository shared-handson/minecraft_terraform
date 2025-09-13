# Amazon Linux 2023 (x86_64) … App 用
data "aws_ami" "al2023_x86" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Amazon Linux 2023 (ARM64) … Proxy/DB 用
data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}
