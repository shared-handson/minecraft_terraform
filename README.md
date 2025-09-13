# Minecraft Server Infrastructure on AWS (Terraform)

このリポジトリは Terraform を使って **Minecraft サーバー基盤** を AWS 上に構築するコードです。  
Proxy (Velocity), App (PaperMC), DB (MariaDB) を分離して管理しやすい構成になっています。

---

## 構成概要

### インスタンス構成
- **Proxy (Velocity)**
  - インスタンスタイプ: `t4g.micro` (ARM)
  - Elastic IP を付与
  - 外部からの接続を受け、App サーバーに中継
  - ディスク: gp3 8GB

- **App (PaperMC)**
  - インスタンスタイプ: `t3a.medium` (x86)
  - PaperMC サーバーを実行
  - Proxy SG からのみ 25565 を許可
  - ディスク: gp3 20GB

- **DB (MariaDB)**
  - インスタンスタイプ: `t4g.micro` (ARM)
  - CoreProtect / LiteBans 用データベース
  - App SG からのみ 3306 を許可
  - ディスク: gp3 10GB

### セキュリティグループ
- Proxy SG  
  - 25565/TCP: 全世界から許可  
  - 22/TCP: 管理用CIDRからのみ
- App SG  
  - 25565/TCP: Proxy SG からのみ許可  
  - 22/TCP: 管理用CIDRからのみ
- DB SG  
  - 3306/TCP: App SG からのみ許可  
  - 22/TCP: 管理用CIDRからのみ

---

## ディレクトリ構成

```

.
├── data.tf          # AMI データソース
├── ec2.tf           # EC2 インスタンス定義 (Proxy, App, DB)
├── network.tf       # セキュリティグループなどネットワーク周り
├── outputs.tf       # 出力値 (EIPやプライベートIPなど)
├── providers.tf     # プロバイダ設定
├── variables.tf     # 変数定義
├── env.tfvars.example  # 変数ファイルのサンプル

````

---

## 前提条件

- AWS アカウントが有効化済み
- Terraform v1.6 以降
- AWS CLI の認証済み (`~/.aws/credentials`)

---

## 使い方

### 初期化
```bash
terraform init
````

### 構文チェック

```bash
terraform validate
```

### 計画の確認

```bash
terraform plan -var-file=env.tfvars
```

### 適用

```bash
terraform apply -var-file=env.tfvars
```

---

## 変数ファイル例 (`env.tfvars.example`)

```hcl
region       = "ap-northeast-1"
name_prefix  = "mc-3tier-mixarch"

vpc_id           = "vpc-xxxxxx"
proxy_subnet_id  = "subnet-xxxxxx"
app_subnet_id    = "subnet-yyyyyy"
db_subnet_id     = "subnet-zzzzzz"

key_name    = "your-keypair"
admin_cidr  = "203.0.113.10/32"

proxy_instance_type = "t4g.micro"
app_instance_type   = "t3a.medium"
db_instance_type    = "t4g.micro"

proxy_public_ip = true
app_public_ip   = true   # セットアップ後に false に変更推奨
db_public_ip    = true   # セットアップ後に false に変更推奨
```

---

## 注意点

* `terraform.tfstate` や `env.tfvars` は **Git管理に含めない**
* `.terraform.lock.hcl` はコミット推奨（プロバイダーのバージョン固定）
* EIP は停止中でも課金対象
* 初期セットアップ時は App/DB に Public IP を付けて外部更新 → その後 Private 化を推奨

---
