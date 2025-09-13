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
    cidr_blocks = [var.admin_cidr]
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
