# Proxy SG
resource "aws_security_group" "proxy_sg" {
  name        = "${var.name_prefix}-proxy-sg"
  description = "Velocity public ingress"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Minecraft public"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-proxy-sg" }
}

# App SG
resource "aws_security_group" "app_sg" {
  name        = "${var.name_prefix}-app-sg"
  description = "PaperMC ingress from Proxy"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Paper from Proxy"
    from_port       = 25565
    to_port         = 25565
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy_sg.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.nat_sg.id]
  }

  egress {
    description = "all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-app-sg" }
}

# DB SG
resource "aws_security_group" "db_sg" {
  name        = "${var.name_prefix}-db-sg"
  description = "DB ingress from App"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from App"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.proxy_sg.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.nat_sg.id]
  }

  egress {
    description = "all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-db-sg" }
}

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

########################################
# ICMP (ping) をVPC内から許可する追記
########################################

# Proxy へ ICMP (VPC内)
resource "aws_security_group_rule" "proxy_icmp" {
  type              = "ingress"
  security_group_id = aws_security_group.proxy_sg.id
  protocol          = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_blocks       = ["172.20.240.0/22"]
  description       = "Allow ICMP (ping) from VPC"
}

# App へ ICMP (VPC内)
resource "aws_security_group_rule" "app_icmp" {
  type              = "ingress"
  security_group_id = aws_security_group.app_sg.id
  protocol          = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_blocks       = ["172.20.240.0/22"]
  description       = "Allow ICMP (ping) from VPC"
}

# DB へ ICMP (VPC内)
resource "aws_security_group_rule" "db_icmp" {
  type              = "ingress"
  security_group_id = aws_security_group.db_sg.id
  protocol          = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_blocks       = ["172.20.240.0/22"]
  description       = "Allow ICMP (ping) from VPC"
}

# NAT へ ICMP (VPC内) - 必要なら
resource "aws_security_group_rule" "nat_icmp" {
  type              = "ingress"
  security_group_id = aws_security_group.nat_sg.id
  protocol          = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_blocks       = ["172.20.240.0/22"]
  description       = "Allow ICMP (ping) from VPC"
}
