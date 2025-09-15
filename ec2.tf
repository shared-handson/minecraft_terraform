# 1) Proxy（Velocity：ARM、Public IP/EIP可）
resource "aws_instance" "proxy" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = var.proxy_instance_type
  key_name                    = var.key_name
  subnet_id                   = var.proxy_subnet_id
  vpc_security_group_ids      = [aws_security_group.proxy_sg.id]
  associate_public_ip_address = var.proxy_public_ip
  iam_instance_profile = aws_iam_instance_profile.proxy_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf -y update
    dnf -y install java-21-amazon-corretto-headless git gcc make tar gzip
    useradd -r -m -d /opt/minecraft -s /bin/bash mc || true
    mkdir -p /opt/minecraft/{velocity,logs}
    chown -R mc:mc /opt/minecraft
    sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm
    sudo systemctl enable amazon-ssm-agent --now
  EOF

  tags = { Name = "${var.name_prefix}-proxy" }
}

# 必要なら固定化のためEIPを割当（Public IPに加えて）
resource "aws_eip" "proxy" {
  count    = var.proxy_public_ip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.proxy.id
  tags     = { Name = "${var.name_prefix}-proxy-eip" }
}

# 2) App（PaperMC：x86、Private推奨）
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023_x86.id
  instance_type               = var.app_instance_type
  key_name                    = var.key_name
  subnet_id                   = var.app_subnet_id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = var.app_public_ip
  iam_instance_profile = aws_iam_instance_profile.app_profile.name
  depends_on = [aws_instance.nat]

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf -y update
    dnf -y install java-21-amazon-corretto-headless git gcc make tar gzip
    useradd -r -m -d /opt/minecraft -s /bin/bash mc || true
    mkdir -p /opt/minecraft/{paper,logs}
    chown -R mc:mc /opt/minecraft
    sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
    sudo systemctl enable amazon-ssm-agent --now
  EOF

  tags = { Name = "${var.name_prefix}-app" }
}

# 3) DB（MariaDB：ARM、Private推奨）
resource "aws_instance" "db" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = var.db_instance_type
  key_name                    = var.key_name
  subnet_id                   = var.db_subnet_id
  vpc_security_group_ids      = [aws_security_group.db_sg.id]
  associate_public_ip_address = var.db_public_ip
  iam_instance_profile = aws_iam_instance_profile.db_profile.name
  depends_on = [aws_instance.nat]

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf -y update
    dnf -y install mariadb105-server
    systemctl enable --now mariadb
    # 省メモリ向けの軽チューニング
    cat >> /etc/my.cnf.d/server.cnf <<'CNF'
    [mysqld]
    bind-address=0.0.0.0
    innodb_buffer_pool_size=256M
    innodb_log_file_size=256M
    innodb_flush_method=O_DIRECT
    innodb_flush_log_at_trx_commit=2
    max_connections=100
    table_open_cache=512
    query_cache_type=0
    CNF
    systemctl restart mariadb
    sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm
    sudo systemctl enable amazon-ssm-agent --now
  EOF

  tags = { Name = "${var.name_prefix}-db" }
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
  iam_instance_profile = aws_iam_instance_profile.nat_profile.name

  # NATには必須（転送機にする）
  source_dest_check = false

  # Public IP（EIPを付けるなら associate_public_ip と EIP を両方）
  associate_public_ip_address = true

  # IPフォワード + MASQUERADE（AL2023はnftables）
  user_data = <<-EOS
#!/bin/bash
dnf install -y iptables-services
systemctl enable --now iptables
/sbin/iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
/sbin/iptables -F FORWARD
service iptables save

echo "net.ipv4.conf.all.forwarding=1" > /etc/sysctl.d/99-sysctl.conf
sysctl -p /etc/sysctl.d/99-sysctl.conf

dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_arm64/amazon-ssm-agent.rpm
systemctl enable --now amazon-ssm-agent

cat << "EOF" > /etc/ssh/sshd_config.d/portforward-only.conf
Match User ec2-user
AllowTcpForwarding yes
X11Forwarding no
AllowAgentForwarding no
PermitTTY no
EOF

systemctl restart sshd
EOS


  tags = { Name = "${var.name_prefix}-nat" }
}
