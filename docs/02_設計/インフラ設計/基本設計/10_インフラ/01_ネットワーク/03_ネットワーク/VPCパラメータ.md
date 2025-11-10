# VPC パラメータシート

## 概要

このドキュメントでは、新潟市介護保険サブシステムで使用するVPCの詳細なパラメータを定義します。

---

## VPC基本設定

### VPC設定

| パラメータ | 本番環境 | ステージング環境 |
|----------|---------|---------------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| 利用可能IP数 | 65,536 | 65,536 |
| DNS Resolution | 有効 | 有効 |
| DNS Hostnames | 有効 | 有効 |
| リージョン | ap-northeast-1 | ap-northeast-1 |
| タグ: Name | kaigo-prod-vpc | kaigo-stg-vpc |
| タグ: Environment | production | staging |
| タグ: Project | niigata-kaigo | niigata-kaigo |

### VPC作成用CloudFormationパラメータ

```yaml
VPCCidr:
  Type: String
  Default: "10.0.0.0/16"
  Description: "VPC CIDR block"
  AllowedPattern: "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\\/(1[6-9]|2[0-8]))$"

EnableDnsSupport:
  Type: String
  Default: "true"
  AllowedValues:
    - "true"
    - "false"

EnableDnsHostnames:
  Type: String
  Default: "true"
  AllowedValues:
    - "true"
    - "false"
```

---

## サブネット設定

### Public Subnet（AZ-A）

| パラメータ | 値 |
|----------|-----|
| サブネット名 | kaigo-prod-public-subnet-a |
| CIDR | 10.0.1.0/24 |
| Availability Zone | ap-northeast-1a |
| 利用可能IP数 | 251 (256 - 5) |
| パブリックIPv4自動割り当て | 有効 |
| 用途 | NAT Gateway, ALB |
| タグ: Name | kaigo-prod-public-a |
| タグ: Type | public |

### Public Subnet（AZ-C）

| パラメータ | 値 |
|----------|-----|
| サブネット名 | kaigo-prod-public-subnet-c |
| CIDR | 10.0.2.0/24 |
| Availability Zone | ap-northeast-1c |
| 利用可能IP数 | 251 (256 - 5) |
| パブリックIPv4自動割り当て | 有効 |
| 用途 | NAT Gateway, ALB |
| タグ: Name | kaigo-prod-public-c |
| タグ: Type | public |

### Private Subnet（AZ-A）

| パラメータ | 値 |
|----------|-----|
| サブネット名 | kaigo-prod-private-subnet-a |
| CIDR | 10.0.11.0/24 |
| Availability Zone | ap-northeast-1a |
| 利用可能IP数 | 251 (256 - 5) |
| パブリックIPv4自動割り当て | 無効 |
| 用途 | ECS Fargate タスク |
| タグ: Name | kaigo-prod-private-a |
| タグ: Type | private |

### Private Subnet（AZ-C）

| パラメータ | 値 |
|----------|-----|
| サブネット名 | kaigo-prod-private-subnet-c |
| CIDR | 10.0.12.0/24 |
| Availability Zone | ap-northeast-1c |
| 利用可能IP数 | 251 (256 - 5) |
| パブリックIPv4自動割り当て | 無効 |
| 用途 | ECS Fargate タスク |
| タグ: Name | kaigo-prod-private-c |
| タグ: Type | private |

### Data Subnet（AZ-A）

| パラメータ | 値 |
|----------|-----|
| サブネット名 | kaigo-prod-data-subnet-a |
| CIDR | 10.0.21.0/24 |
| Availability Zone | ap-northeast-1a |
| 利用可能IP数 | 251 (256 - 5) |
| パブリックIPv4自動割り当て | 無効 |
| 用途 | RDS Primary, ElastiCache Primary |
| タグ: Name | kaigo-prod-data-a |
| タグ: Type | data |

### Data Subnet（AZ-C）

| パラメータ | 値 |
|----------|-----|
| サブネット名 | kaigo-prod-data-subnet-c |
| CIDR | 10.0.22.0/24 |
| Availability Zone | ap-northeast-1c |
| 利用可能IP数 | 251 (256 - 5) |
| パブリックIPv4自動割り当て | 無効 |
| 用途 | RDS Standby, ElastiCache Replica |
| タグ: Name | kaigo-prod-data-c |
| タグ: Type | data |

### サブネット作成用CloudFormationパラメータ

```yaml
PublicSubnetACidr:
  Type: String
  Default: "10.0.1.0/24"

PublicSubnetCCidr:
  Type: String
  Default: "10.0.2.0/24"

PrivateSubnetACidr:
  Type: String
  Default: "10.0.11.0/24"

PrivateSubnetCCidr:
  Type: String
  Default: "10.0.12.0/24"

DataSubnetACidr:
  Type: String
  Default: "10.0.21.0/24"

DataSubnetCCidr:
  Type: String
  Default: "10.0.22.0/24"
```

---

## Internet Gateway

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-igw |
| アタッチ先VPC | kaigo-prod-vpc |
| タグ: Name | kaigo-prod-igw |
| タグ: Environment | production |

### CloudFormationパラメータ

```yaml
InternetGatewayName:
  Type: String
  Default: "kaigo-prod-igw"
```

---

## NAT Gateway

### NAT Gateway A（AZ-A）

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-nat-a |
| 配置サブネット | kaigo-prod-public-subnet-a |
| Elastic IP | 自動割り当て |
| 最大帯域 | 5 Gbps |
| タグ: Name | kaigo-prod-nat-a |
| タグ: AZ | ap-northeast-1a |

### NAT Gateway C（AZ-C）

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-nat-c |
| 配置サブネット | kaigo-prod-public-subnet-c |
| Elastic IP | 自動割り当て |
| 最大帯域 | 5 Gbps |
| タグ: Name | kaigo-prod-nat-c |
| タグ: AZ | ap-northeast-1c |

---

## ルートテーブル

### Public Route Table

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-public-rt |
| 関連付けサブネット | kaigo-prod-public-subnet-a, kaigo-prod-public-subnet-c |
| タグ: Name | kaigo-prod-public-rt |
| タグ: Type | public |

**ルート設定**

| Destination | Target | 説明 |
|------------|--------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | igw-xxxxx | インターネット通信 |
| 172.16.0.0/12 | vgw-xxxxx | 基幹システム通信（VPN経由） |

### Private Route Table A

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-private-rt-a |
| 関連付けサブネット | kaigo-prod-private-subnet-a |
| タグ: Name | kaigo-prod-private-rt-a |
| タグ: Type | private |
| タグ: AZ | ap-northeast-1a |

**ルート設定**

| Destination | Target | 説明 |
|------------|--------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | nat-xxxxx (AZ-A) | インターネット通信（NAT Gateway A経由） |
| 172.16.0.0/12 | vgw-xxxxx | 基幹システム通信（VPN経由） |

### Private Route Table C

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-private-rt-c |
| 関連付けサブネット | kaigo-prod-private-subnet-c |
| タグ: Name | kaigo-prod-private-rt-c |
| タグ: Type | private |
| タグ: AZ | ap-northeast-1c |

**ルート設定**

| Destination | Target | 説明 |
|------------|--------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | nat-xxxxx (AZ-C) | インターネット通信（NAT Gateway C経由） |
| 172.16.0.0/12 | vgw-xxxxx | 基幹システム通信（VPN経由） |

### Data Route Table

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-data-rt |
| 関連付けサブネット | kaigo-prod-data-subnet-a, kaigo-prod-data-subnet-c |
| タグ: Name | kaigo-prod-data-rt |
| タグ: Type | data |

**ルート設定**

| Destination | Target | 説明 |
|------------|--------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 172.16.0.0/12 | vgw-xxxxx | 基幹システム通信（必要な場合） |

**注意**: Data Subnetはインターネットへのルートなし（セキュリティ強化）

---

## セキュリティグループ

### ALB Security Group

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-alb-sg |
| 説明 | Security group for Application Load Balancer |
| VPC | kaigo-prod-vpc |
| タグ: Name | kaigo-prod-alb-sg |

**Inbound Rules**

| Type | Protocol | Port Range | Source | 説明 |
|------|----------|-----------|--------|------|
| HTTPS | TCP | 443 | 0.0.0.0/0 | インターネットからのHTTPS |
| HTTP | TCP | 80 | 0.0.0.0/0 | HTTP→HTTPS リダイレクト用 |

**Outbound Rules**

| Type | Protocol | Port Range | Destination | 説明 |
|------|----------|-----------|-------------|------|
| Custom TCP | TCP | 8080 | kaigo-prod-ecs-sg | ECSタスクへのHTTP |

### ECS Security Group

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-ecs-sg |
| 説明 | Security group for ECS Fargate tasks |
| VPC | kaigo-prod-vpc |
| タグ: Name | kaigo-prod-ecs-sg |

**Inbound Rules**

| Type | Protocol | Port Range | Source | 説明 |
|------|----------|-----------|--------|------|
| Custom TCP | TCP | 8080 | kaigo-prod-alb-sg | ALBからのHTTP |

**Outbound Rules**

| Type | Protocol | Port Range | Destination | 説明 |
|------|----------|-----------|-------------|------|
| MySQL/Aurora | TCP | 3306 | kaigo-prod-rds-sg | RDSへのMySQL接続 |
| Custom TCP | TCP | 6379 | kaigo-prod-redis-sg | Redisへの接続 |
| HTTPS | TCP | 443 | 0.0.0.0/0 | 外部API呼び出し |

### RDS Security Group

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-rds-sg |
| 説明 | Security group for RDS MySQL |
| VPC | kaigo-prod-vpc |
| タグ: Name | kaigo-prod-rds-sg |

**Inbound Rules**

| Type | Protocol | Port Range | Source | 説明 |
|------|----------|-----------|--------|------|
| MySQL/Aurora | TCP | 3306 | kaigo-prod-ecs-sg | ECSからのMySQL接続 |

**Outbound Rules**

| Type | Protocol | Port Range | Destination | 説明 |
|------|----------|-----------|-------------|------|
| なし | - | - | - | Egressトラフィックなし |

### ElastiCache Security Group

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-redis-sg |
| 説明 | Security group for ElastiCache Redis |
| VPC | kaigo-prod-vpc |
| タグ: Name | kaigo-prod-redis-sg |

**Inbound Rules**

| Type | Protocol | Port Range | Source | 説明 |
|------|----------|-----------|--------|------|
| Custom TCP | TCP | 6379 | kaigo-prod-ecs-sg | ECSからのRedis接続 |

**Outbound Rules**

| Type | Protocol | Port Range | Destination | 説明 |
|------|----------|-----------|-------------|------|
| なし | - | - | - | Egressトラフィックなし |

---

## ネットワークACL

### Public Subnet NACL

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-public-nacl |
| 関連付けサブネット | kaigo-prod-public-subnet-a, kaigo-prod-public-subnet-c |
| タグ: Name | kaigo-prod-public-nacl |

**Inbound Rules**

| Rule # | Protocol | Port Range | Source | Allow/Deny |
|--------|----------|-----------|--------|------------|
| 100 | TCP | 443 | 0.0.0.0/0 | ALLOW |
| 110 | TCP | 80 | 0.0.0.0/0 | ALLOW |
| 120 | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All | All | 0.0.0.0/0 | DENY |

**Outbound Rules**

| Rule # | Protocol | Port Range | Destination | Allow/Deny |
|--------|----------|-----------|-------------|------------|
| 100 | TCP | 80 | 0.0.0.0/0 | ALLOW |
| 110 | TCP | 443 | 0.0.0.0/0 | ALLOW |
| 120 | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All | All | 0.0.0.0/0 | DENY |

### Private Subnet NACL

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-private-nacl |
| 関連付けサブネット | kaigo-prod-private-subnet-a, kaigo-prod-private-subnet-c |
| タグ: Name | kaigo-prod-private-nacl |

**Inbound Rules**

| Rule # | Protocol | Port Range | Source | Allow/Deny |
|--------|----------|-----------|--------|------------|
| 100 | TCP | 8080 | 10.0.1.0/24 | ALLOW |
| 110 | TCP | 8080 | 10.0.2.0/24 | ALLOW |
| 120 | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All | All | 0.0.0.0/0 | DENY |

**Outbound Rules**

| Rule # | Protocol | Port Range | Destination | Allow/Deny |
|--------|----------|-----------|-------------|------------|
| 100 | TCP | 3306 | 10.0.21.0/24 | ALLOW |
| 110 | TCP | 3306 | 10.0.22.0/24 | ALLOW |
| 120 | TCP | 6379 | 10.0.21.0/24 | ALLOW |
| 130 | TCP | 6379 | 10.0.22.0/24 | ALLOW |
| 140 | TCP | 443 | 0.0.0.0/0 | ALLOW |
| 150 | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All | All | 0.0.0.0/0 | DENY |

### Data Subnet NACL

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-data-nacl |
| 関連付けサブネット | kaigo-prod-data-subnet-a, kaigo-prod-data-subnet-c |
| タグ: Name | kaigo-prod-data-nacl |

**Inbound Rules**

| Rule # | Protocol | Port Range | Source | Allow/Deny |
|--------|----------|-----------|--------|------------|
| 100 | TCP | 3306 | 10.0.11.0/24 | ALLOW |
| 110 | TCP | 3306 | 10.0.12.0/24 | ALLOW |
| 120 | TCP | 6379 | 10.0.11.0/24 | ALLOW |
| 130 | TCP | 6379 | 10.0.12.0/24 | ALLOW |
| * | All | All | 0.0.0.0/0 | DENY |

**Outbound Rules**

| Rule # | Protocol | Port Range | Destination | Allow/Deny |
|--------|----------|-----------|-------------|------------|
| 100 | TCP | 1024-65535 | 10.0.11.0/24 | ALLOW |
| 110 | TCP | 1024-65535 | 10.0.12.0/24 | ALLOW |
| 120 | TCP | 3306 | 10.0.22.0/24 | ALLOW |
| 130 | TCP | 6379 | 10.0.22.0/24 | ALLOW |
| * | All | All | 0.0.0.0/0 | DENY |

---

## VPC Flow Logs

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-vpc-flow-logs |
| 対象リソース | kaigo-prod-vpc（VPC全体） |
| フィルター | すべて（ACCEPT + REJECT） |
| 送信先 | CloudWatch Logs |
| ロググループ名 | /aws/vpc/kaigo-prod |
| 保管期間 | 90日 |
| IAM Role | kaigo-prod-vpc-flow-logs-role |
| タグ: Name | kaigo-prod-vpc-flow-logs |

### CloudFormationパラメータ

```yaml
FlowLogsLogGroupName:
  Type: String
  Default: "/aws/vpc/kaigo-prod"

FlowLogsRetentionDays:
  Type: Number
  Default: 90
  AllowedValues:
    - 1
    - 3
    - 5
    - 7
    - 14
    - 30
    - 60
    - 90
    - 120
    - 150
    - 180
    - 365
    - 400
    - 545
    - 731
    - 1827
    - 3653

FlowLogsTrafficType:
  Type: String
  Default: "ALL"
  AllowedValues:
    - "ACCEPT"
    - "REJECT"
    - "ALL"
```

---

## VPN接続（基幹システム連携）

### Virtual Private Gateway

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-vgw |
| タイプ | VPN |
| ASN | 64512（デフォルト） |
| アタッチ先VPC | kaigo-prod-vpc |
| タグ: Name | kaigo-prod-vgw |

### Customer Gateway

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-cgw |
| ルーティング | Dynamic (BGP) |
| BGP ASN | 65000（オンプレミス側で設定） |
| IPアドレス | xxx.xxx.xxx.xxx（新潟市データセンターのパブリックIP） |
| タグ: Name | kaigo-prod-cgw |

### Site-to-Site VPN Connection

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-vpn |
| Virtual Private Gateway | kaigo-prod-vgw |
| Customer Gateway | kaigo-prod-cgw |
| ルーティングオプション | Dynamic (BGP) |
| トンネル数 | 2（冗長化） |
| 暗号化アルゴリズム | AES-256 |
| IKE バージョン | IKEv2 |
| DPD Timeout | 30秒 |
| タグ: Name | kaigo-prod-vpn |

**トンネル1設定**

| パラメータ | 値 |
|----------|-----|
| トンネルインサイドCIDR | 169.254.10.0/30 |
| Pre-Shared Key | （自動生成） |
| 暗号化 | AES-256 |
| ハッシュ | SHA-256 |

**トンネル2設定**

| パラメータ | 値 |
|----------|-----|
| トンネルインサイドCIDR | 169.254.11.0/30 |
| Pre-Shared Key | （自動生成） |
| 暗号化 | AES-256 |
| ハッシュ | SHA-256 |

---

## VPCエンドポイント（PrivateLink）

### S3 VPCエンドポイント（Gateway型）

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-s3-endpoint |
| サービス名 | com.amazonaws.ap-northeast-1.s3 |
| タイプ | Gateway |
| ルートテーブル | kaigo-prod-private-rt-a, kaigo-prod-private-rt-c |
| ポリシー | Full Access |
| タグ: Name | kaigo-prod-s3-endpoint |

### ECR API VPCエンドポイント（Interface型）

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-ecr-api-endpoint |
| サービス名 | com.amazonaws.ap-northeast-1.ecr.api |
| タイプ | Interface |
| サブネット | kaigo-prod-private-subnet-a, kaigo-prod-private-subnet-c |
| セキュリティグループ | kaigo-prod-vpc-endpoint-sg |
| プライベートDNS | 有効 |
| タグ: Name | kaigo-prod-ecr-api-endpoint |

### ECR DKR VPCエンドポイント（Interface型）

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-ecr-dkr-endpoint |
| サービス名 | com.amazonaws.ap-northeast-1.ecr.dkr |
| タイプ | Interface |
| サブネット | kaigo-prod-private-subnet-a, kaigo-prod-private-subnet-c |
| セキュリティグループ | kaigo-prod-vpc-endpoint-sg |
| プライベートDNS | 有効 |
| タグ: Name | kaigo-prod-ecr-dkr-endpoint |

### CloudWatch Logs VPCエンドポイント（Interface型）

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-logs-endpoint |
| サービス名 | com.amazonaws.ap-northeast-1.logs |
| タイプ | Interface |
| サブネット | kaigo-prod-private-subnet-a, kaigo-prod-private-subnet-c |
| セキュリティグループ | kaigo-prod-vpc-endpoint-sg |
| プライベートDNS | 有効 |
| タグ: Name | kaigo-prod-logs-endpoint |

### VPCエンドポイント用セキュリティグループ

| パラメータ | 値 |
|----------|-----|
| 名前 | kaigo-prod-vpc-endpoint-sg |
| 説明 | Security group for VPC endpoints |
| VPC | kaigo-prod-vpc |
| タグ: Name | kaigo-prod-vpc-endpoint-sg |

**Inbound Rules**

| Type | Protocol | Port Range | Source | 説明 |
|------|----------|-----------|--------|------|
| HTTPS | TCP | 443 | 10.0.0.0/16 | VPC内からのHTTPS |

---

## CIDR予約と将来の拡張計画

### 現在使用中のCIDR

| サブネット | CIDR | 用途 |
|----------|------|------|
| Public Subnet A | 10.0.1.0/24 | NAT Gateway, ALB |
| Public Subnet C | 10.0.2.0/24 | NAT Gateway, ALB |
| Private Subnet A | 10.0.11.0/24 | ECS Fargate |
| Private Subnet C | 10.0.12.0/24 | ECS Fargate |
| Data Subnet A | 10.0.21.0/24 | RDS, ElastiCache |
| Data Subnet C | 10.0.22.0/24 | RDS, ElastiCache |

### 予約済みCIDR（将来の拡張用）

| サブネット | CIDR | 用途（予定） |
|----------|------|----------|
| Public Subnet D | 10.0.3.0/24 | AZ-D追加時 |
| Private Subnet D | 10.0.13.0/24 | AZ-D追加時 |
| Data Subnet D | 10.0.23.0/24 | AZ-D追加時 |
| 予備 | 10.0.4.0/24 ～ 10.0.10.0/24 | 将来の用途 |

---

## タグ戦略

### すべてのVPCリソースに適用する共通タグ

| タグキー | タグ値（本番） | タグ値（ステージング） |
|---------|-------------|-------------------|
| Project | niigata-kaigo | niigata-kaigo |
| Environment | production | staging |
| ManagedBy | CloudFormation | CloudFormation |
| CostCenter | IT-Infrastructure | IT-Infrastructure |
| Owner | architect@niigata.lg.jp | architect@niigata.lg.jp |

---

## ステージング環境のVPCパラメータ

### VPC基本設定（ステージング）

| パラメータ | 値 |
|----------|-----|
| VPC CIDR | 10.1.0.0/16 |
| Public Subnet A | 10.1.1.0/24 |
| Public Subnet C | 10.1.2.0/24 |
| Private Subnet A | 10.1.11.0/24 |
| Private Subnet C | 10.1.12.0/24 |
| Data Subnet A | 10.1.21.0/24 |
| Data Subnet C | 10.1.22.0/24 |

**注意**: ステージング環境では本番環境と同じ構成だが、VPC CIDRを分けることでVPCピアリングが可能

---

## まとめ

- **VPC CIDR**: 10.0.0.0/16（本番）、10.1.0.0/16（ステージング）
- **サブネット**: 2つのAZ × 3種類（Public/Private/Data）
- **NAT Gateway**: 各AZに1つずつ（高可用性）
- **セキュリティグループ**: 最小権限の原則
- **VPCエンドポイント**: Private Subnet からのAWSサービスアクセス
- **VPN接続**: 基幹システムとの連携

---

**作成者**: architect
**レビュー状態**: Draft
**関連ドキュメント**: [network_design.md](network_design.md), [network_diagram.md](network_diagram.md)
