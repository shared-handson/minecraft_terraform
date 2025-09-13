# 1) Proxy（Velocity：ARM、Public IP/EIP可）
resource "aws_instance" "proxy" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = var.proxy_instance_type
  key_name                    = var.key_name
  subnet_id                   = var.proxy_subnet_id
  vpc_security_group_ids      = [aws_security_group.proxy_sg.id]
  associate_public_ip_address = var.proxy_public_ip

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
  EOF

  tags = { Name = "${var.name_prefix}-db" }
}

