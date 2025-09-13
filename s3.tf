############################
# S3.tf - Paper バックアップ
############################

# ===== Vars =====
variable "s3_backup_bucket_name" {
  description = "バックアップ先S3バケット名（グローバル唯一）"
  type        = string
}

variable "s3_backup_prefix" {
  description = "バックアップを保存するプレフィックス（末尾に / 推奨）"
  type        = string
  default     = "paper-backups/"
}

# ===== Region (for VPC Endpoint service name) =====
data "aws_region" "current" {}

# ===== S3 Bucket =====
resource "aws_s3_bucket" "paper_backup" {
  bucket = var.s3_backup_bucket_name

  tags = {
    Name  = var.s3_backup_bucket_name
    Usage = "paper-backup"
  }
}

# バケットの公開遮断
resource "aws_s3_bucket_public_access_block" "paper_backup" {
  bucket                  = aws_s3_bucket.paper_backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# バージョニング
resource "aws_s3_bucket_versioning" "paper_backup" {
  bucket = aws_s3_bucket.paper_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# サーバサイド暗号化
resource "aws_s3_bucket_server_side_encryption_configuration" "paper_backup" {
  bucket = aws_s3_bucket.paper_backup.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ライフサイクルルール
resource "aws_s3_bucket_lifecycle_configuration" "paper_backup" {
  bucket = aws_s3_bucket.paper_backup.id

  rule {
    id     = "optimize-cost"
    status = "Enabled"

    filter { prefix = var.s3_backup_prefix }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ===== S3 Gateway VPC Endpoint =====
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = var.private_route_table_ids

  tags = {
    Name = "vpce-s3-${data.aws_region.current.name}"
  }
}

# ===== Bucket Policy =====
data "aws_iam_policy_document" "paper_backup_bucket_policy" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals { type = "*", identifiers = ["*"] }
    resources = [
      aws_s3_bucket.paper_backup.arn,
      "${aws_s3_bucket.paper_backup.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "AllowOnlyViaThisVPCEndpoint"
    effect  = "Deny"
    actions = ["s3:*"]
    principals { type = "*", identifiers = ["*"] }
    resources = [
      aws_s3_bucket.paper_backup.arn,
      "${aws_s3_bucket.paper_backup.arn}/*"
    ]
    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.s3.id]
    }
  }
}

resource "aws_s3_bucket_policy" "paper_backup" {
  bucket = aws_s3_bucket.paper_backup.id
  policy = data.aws_iam_policy_document.paper_backup_bucket_policy.json
}

# ===== IAM Role for App =====

# AssumeRole policy for EC2
data "aws_iam_policy_document" "app_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# App Role
resource "aws_iam_role" "app_role" {
  name               = "${var.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role.json
}

# Instance Profile (EC2にアタッチ用)
resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.name_prefix}-app-profile"
  role = aws_iam_role.app_role.name
}

# App専用 S3 アクセスポリシー
data "aws_iam_policy_document" "app_s3_backup" {
  statement {
    sid     = "ListBucketPrefix"
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [aws_s3_bucket.paper_backup.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [var.s3_backup_prefix]
    }
  }

  statement {
    sid     = "PutGetObjectsUnderPrefix"
    effect  = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${aws_s3_bucket.paper_backup.arn}/${var.s3_backup_prefix}*"]
  }
}

resource "aws_iam_policy" "app_s3_backup" {
  name   = "${var.name_prefix}-app-s3-backup"
  path   = "/"
  policy = data.aws_iam_policy_document.app_s3_backup.json
}

# ポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "app_s3_backup_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_s3_backup.arn
}

