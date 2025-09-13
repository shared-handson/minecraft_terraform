# ========== NAT SG ==========
resource "aws_security_group" "nat_sg" {
  name        = "${var.name_prefix}-nat-sg"
  description = "SG for NAT instance"
  vpc_id      = var.vpc_id

  # 管理用（必要なら）
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # プライベート側からのフォワード対象（VPCのIPv4に合わせる）
  ingress {
    description = "from private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.20.240.0/22"]
  }

  # 外向けはフル許可（戻り通信のため）
  egress {
    description = "all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-nat-sg" }
}

# ========== NAT instance ==========
# ARMで安く行く例（x86がよければ AL2023 x86 のAMIデータソースに差し替え）
# data.aws_ami.al2023_arm は既存 data.tf に合わせてね。無ければ作成を。
resource "aws_instance" "nat" {
  ami                    = data.aws_ami.al2023_arm.id
  instance_type          = "t4g.nano"
  subnet_id              = var.proxy_subnet_id # Publicサブネットに置く
  vpc_security_group_ids = [aws_security_group.nat_sg.id]
  key_name               = var.key_name

  # NATには必須（転送機にする）
  source_dest_check = false

  # Public IP（EIPを付けるなら associate_public_ip と EIP を両方）
  associate_public_ip_address = true

  # IPフォワード + MASQUERADE（AL2023はnftables）
  user_data = <<-EOS
    #!/bin/bash
    set -euxo pipefail

    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-nat.conf
    sysctl -p /etc/sysctl.d/99-nat.conf
    dnf install -y nftables

    IFACE=$(ip -o -4 route show to default | awk '{print $5}')
    cat >/etc/nftables.conf <<'NFT'
    flush ruleset
    table inet filter {
      chain input   { type filter hook input   priority 0; policy accept; }
      chain forward { type filter hook forward priority 0; policy accept; }
      chain output  { type filter hook output  priority 0; policy accept; }
    }
    table ip nat {
      chain prerouting  { type nat hook prerouting  priority -100; }
      chain postrouting { type nat hook postrouting priority 100;  }
    }
NFT
    nft -f /etc/nftables.conf
    nft add rule ip nat postrouting oifname "$IFACE" masquerade
    systemctl enable --now nftables

    dnf -y update || true
  EOS

  tags = { Name = "${var.name_prefix}-nat" }
}

# 固定したいなら（任意）EIP
resource "aws_eip" "nat" {
  domain   = "vpc"
  instance = aws_instance.nat.id
  tags     = { Name = "${var.name_prefix}-nat-eip" }
}

