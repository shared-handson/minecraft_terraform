variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "name_prefix" {
  type    = string
  default = "mc-3tier-mixarch"
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID (vpc-xxxx)"
}

variable "proxy_subnet_id" {
  type        = string
  description = "Proxy subnet ID (Public recommended)"
}

variable "app_subnet_id" {
  type        = string
  description = "App subnet ID (Private recommended)"
}

variable "db_subnet_id" {
  type        = string
  description = "DB subnet ID (Private recommended)"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name"
}

variable "admin_cidr" {
  type        = string
  description = "Your admin IP/CIDR (e.g. 203.0.113.10/32)"
}

variable "proxy_instance_type" {
  type    = string
  default = "t4g.micro"
}

variable "app_instance_type" {
  type    = string
  default = "t3a.medium"
}

variable "db_instance_type" {
  type    = string
  default = "t4g.micro"
}

variable "proxy_public_ip" {
  type    = bool
  default = true
}

variable "app_public_ip" {
  type    = bool
  default = false
}

variable "db_public_ip" {
  type    = bool
  default = false
}

variable "private_route_table_ids" {
  type        = list(string)
  description = "Private route tables that need default route to NAT"
}
