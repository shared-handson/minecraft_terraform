# ------------------------------------------------------
# 共通: EC2 Assume Role Policy Document
# ------------------------------------------------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ------------------------------------------------------
# 共通: SSM Core ポリシー
# ------------------------------------------------------
data "aws_iam_policy" "ssm_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ======================================================
# Proxy Role
# ======================================================
resource "aws_iam_role" "proxy_role" {
  name               = "${var.name_prefix}-proxy-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  path               = "/"
  tags = {
    Name        = "${var.name_prefix}-proxy-role"
  }
}

resource "aws_iam_instance_profile" "proxy_profile" {
  name = "${var.name_prefix}-proxy-profile"
  role = aws_iam_role.proxy_role.name
}

resource "aws_iam_role_policy_attachment" "proxy_ssm" {
  role       = aws_iam_role.proxy_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

# ======================================================
# NAT Role
# ======================================================
resource "aws_iam_role" "nat_role" {
  name               = "${var.name_prefix}-nat-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  path               = "/"
  tags = {
    Name        = "${var.name_prefix}-nat-role"
  }
}

resource "aws_iam_instance_profile" "nat_profile" {
  name = "${var.name_prefix}-nat-profile"
  role = aws_iam_role.nat_role.name
}

resource "aws_iam_role_policy_attachment" "nat_ssm" {
  role       = aws_iam_role.nat_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

# ======================================================
# App Role（将来拡張用。今はSSMのみ）
# ======================================================
resource "aws_iam_role" "app_role" {
  name               = "${var.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  path               = "/"
  tags = {
    Name        = "${var.name_prefix}-app-role"
  }
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.name_prefix}-app-profile"
  role = aws_iam_role.app_role.name
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

# ======================================================
# DB Role（将来拡張用。今はSSMのみ）
# ======================================================
resource "aws_iam_role" "db_role" {
  name               = "${var.name_prefix}-db-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  path               = "/"
  tags = {
    Name        = "${var.name_prefix}-db-role"
  }
}

resource "aws_iam_instance_profile" "db_profile" {
  name = "${var.name_prefix}-db-profile"
  role = aws_iam_role.db_role.name
}

resource "aws_iam_role_policy_attachment" "db_ssm" {
  role       = aws_iam_role.db_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

