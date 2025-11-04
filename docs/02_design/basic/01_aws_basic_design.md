# AWS基本設計書 - 新潟市介護保険事業所システム

## ドキュメント管理情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | AWS基本設計書 |
| バージョン | 1.0.0 |
| 作成日 | 2025-11-04 |
| 最終更新日 | 2025-11-04 |
| ステータス | Draft |

---

## 目次

1. [設計概要](#1-設計概要)
2. [AWS Organizations構成](#2-aws-organizations構成)
3. [マルチアカウント戦略](#3-マルチアカウント戦略)
4. [ネットワークアーキテクチャ](#4-ネットワークアーキテクチャ)
5. [セキュリティアーキテクチャ](#5-セキュリティアーキテクチャ)
6. [コンピューティングアーキテクチャ](#6-コンピューティングアーキテクチャ)
7. [データアーキテクチャ](#7-データアーキテクチャ)
8. [運用アーキテクチャ](#8-運用アーキテクチャ)
9. [ディザスタリカバリ戦略](#9-ディザスタリカバリ戦略)
10. [コスト最適化戦略](#10-コスト最適化戦略)

---

## 1. 設計概要

### 1.1 設計方針

本設計は以下の方針に基づいて策定されています：

1. **GCAS準拠**: 政府情報システムのためのセキュリティ評価制度に完全準拠
2. **マルチアカウント戦略**: 環境分離とセキュリティ強化のための複数アカウント構成
3. **高可用性**: Multi-AZ構成による99.0%以上の可用性確保
4. **スケーラビリティ**: Auto Scalingによる負荷変動への自動対応
5. **セキュリティ**: 多層防御によるセキュリティ確保
6. **運用自動化**: IaCとCI/CDによる自動化、Bedrockによる運用効率化
7. **コスト最適化**: T系インスタンス活用とリザーブドインスタンスによるコスト削減

### 1.2 全体アーキテクチャ概要図

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Organizations                           │
│                      (niigatacity-org)                              │
└─────────────────────────────────────────────────────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
┌───────────────┐        ┌───────────────┐      ┌──────────────────┐
│ Management    │        │ Security      │      │ Workload OUs     │
│ OU            │        │ OU            │      │                  │
│               │        │               │      │  ├─ Production   │
│ ├─ Billing    │        │ ├─ Audit     │      │  ├─ Staging      │
│ ├─ Logging    │        │ └─ Security  │      │  └─ Operations   │
└───────────────┘        └───────────────┘      └──────────────────┘
```

### 1.3 主要AWSサービス選定

| カテゴリ | サービス | 選定理由 |
|---------|---------|---------|
| コンピューティング | ECS Fargate | サーバーレスコンテナ実行、運用負荷軽減 |
| データベース | RDS PostgreSQL | マネージドDB、Multi-AZ対応 |
| ネットワーク | Transit Gateway | マルチアカウント間接続の中心 |
| ネットワーク | Direct Connect | 専用線接続、低レイテンシ |
| CDN | CloudFront | グローバルエッジ配信、高速化 |
| ストレージ | S3 | 高耐久性オブジェクトストレージ |
| 認証 | Cognito | マネージド認証、MFA対応 |
| 監視 | CloudWatch | 統合監視、ログ集約 |
| セキュリティ | Security Hub | セキュリティ状態の一元管理 |
| セキュリティ | GuardDuty | 脅威検出 |
| セキュリティ | WAF | Web Application Firewall |
| AI/ML | Bedrock | 運用自動化、一次調査支援 |

---

## 2. AWS Organizations構成

### 2.1 組織構造

```
niigatacity-org (Root)
│
├── Management OU
│   └── management-account (ルートアカウント)
│       ├── AWS Organizations管理
│       ├── 一括請求管理
│       ├── CloudTrail組織トレイル
│       └── AWS Config集約
│
├── Security OU
│   ├── audit-account (監査アカウント)
│   │   ├── CloudTrailログ保管
│   │   ├── Config履歴保管
│   │   └── GuardDuty管理アカウント
│   │
│   └── security-account (セキュリティアカウント)
│       ├── Security Hub集約
│       ├── IAM Identity Center
│       └── セキュリティツール管理
│
├── Production OU
│   ├── common-account (共通系アカウント)
│   │   ├── Direct Connect
│   │   ├── Transit Gateway
│   │   ├── Network Firewall
│   │   ├── Route 53 (プライベートホストゾーン)
│   │   └── VPC (共通サービス用)
│   │
│   └── prod-app-account (本番アプリケーションアカウント)
│       ├── ECS Fargate
│       ├── RDS PostgreSQL (Multi-AZ)
│       ├── ElastiCache Redis
│       ├── S3 (データ保管)
│       └── CloudFront
│
├── Staging OU
│   └── staging-account (ステージングアカウント)
│       ├── ECS Fargate (T系インスタンス)
│       ├── RDS PostgreSQL (Single-AZ)
│       └── S3 (テストデータ)
│
└── Operations OU
    └── operations-account (運用アカウント)
        ├── CloudWatch Logs集約
        ├── CloudWatch Dashboards
        ├── Lambda (Bedrock連携)
        ├── SNS (アラート通知)
        ├── Backup Vault (集中バックアップ)
        └── Systems Manager (パラメータストア)
```

### 2.2 アカウント一覧

| アカウント名 | アカウントID (例) | 用途 | 主要サービス |
|-------------|------------------|------|-------------|
| management-account | 111111111111 | Organizations管理、請求 | Organizations, Billing |
| audit-account | 222222222222 | 監査ログ保管 | CloudTrail, Config, S3 |
| security-account | 333333333333 | セキュリティ管理 | Security Hub, GuardDuty, IAM IC |
| common-account | 444444444444 | 共通ネットワーク | Direct Connect, TGW, Network FW |
| prod-app-account | 555555555555 | 本番アプリケーション | ECS, RDS, S3, CloudFront |
| staging-account | 666666666666 | ステージング環境 | ECS, RDS (T系) |
| operations-account | 777777777777 | 運用・監視 | CloudWatch, Lambda, Backup |

### 2.3 Service Control Policies (SCP)

#### 2.3.1 全アカウント共通SCP

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedS3Upload",
      "Effect": "Deny",
      "Action": "s3:PutObject",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": ["AES256", "aws:kms"]
        }
      }
    },
    {
      "Sid": "DenyNonTokyoOsakaRegions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["ap-northeast-1", "ap-northeast-3"]
        }
      }
    },
    {
      "Sid": "DenyRootAccountUsage",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
      }
    }
  ]
}
```

#### 2.3.2 Production OU用SCP

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInstanceTypeChange",
      "Effect": "Deny",
      "Action": [
        "ec2:ModifyInstanceAttribute",
        "rds:ModifyDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:role/AdminRole"
        }
      }
    },
    {
      "Sid": "RequireMFAForDeletion",
      "Effect": "Deny",
      "Action": [
        "rds:DeleteDBInstance",
        "s3:DeleteBucket",
        "dynamodb:DeleteTable"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

---

## 3. マルチアカウント戦略

### 3.1 アカウント分離の目的

| 目的 | 説明 | 該当アカウント |
|-----|------|--------------|
| 環境分離 | 本番とステージングの完全分離 | prod-app-account, staging-account |
| セキュリティ境界 | 侵害時の影響範囲限定 | 全アカウント |
| 権限管理 | 最小権限の原則を適用 | 全アカウント |
| コスト管理 | 環境別コスト可視化 | 各Workloadアカウント |
| 監査要件 | ログの改ざん防止 | audit-account |
| ネットワーク集約 | 共通ネットワーク機能の集中管理 | common-account |
| 運用効率化 | 監視・バックアップの集中管理 | operations-account |

### 3.2 クロスアカウントアクセスパターン

#### 3.2.1 運用アカウントからの監視アクセス

```
operations-account
    │
    ├─ (IAM Role Assumption) ──> prod-app-account/MonitoringRole
    │                              └─ CloudWatch Metrics読み取り
    │
    └─ (IAM Role Assumption) ──> staging-account/MonitoringRole
                                   └─ CloudWatch Metrics読み取り
```

#### 3.2.2 セキュリティアカウントからの監査アクセス

```
security-account
    │
    ├─ Security Hub (集約) ◄── prod-app-account
    ├─ Security Hub (集約) ◄── staging-account
    └─ Security Hub (集約) ◄── common-account

audit-account
    │
    └─ S3 Bucket (CloudTrail) ◄── 全アカウントのCloudTrailログ
```

#### 3.2.3 バックアップアカウントからのバックアップアクセス

```
operations-account/AWS Backup
    │
    ├─ (Role Assumption) ──> prod-app-account/BackupRole
    │                          └─ RDS Snapshot, EBS Snapshot作成
    │
    └─ (Role Assumption) ──> staging-account/BackupRole
                               └─ RDS Snapshot作成
```

### 3.3 IAM Identity Center統合

#### 3.3.1 Permission Sets定義

| Permission Set名 | 対象アカウント | 権限範囲 | 対象ユーザー |
|-----------------|--------------|---------|------------|
| AdminAccess | management-account | AdministratorAccess | システム管理者 |
| NetworkAdmin | common-account | ネットワーク管理権限 | ネットワーク管理者 |
| AppAdmin | prod-app-account, staging-account | アプリケーション管理権限 | アプリケーション管理者 |
| Developer | staging-account | 開発者権限（読み取り+デプロイ） | 開発者 |
| ReadOnly | 全アカウント | 読み取り専用 | 監査担当者 |
| SecurityAdmin | security-account | セキュリティ管理権限 | セキュリティ担当者 |
| OperationsAdmin | operations-account | 運用管理権限 | 運用担当者 |

#### 3.3.2 グループ構成

```
IdentityCenter Groups
├── Administrators (管理者)
│   └── Permission: AdminAccess → management-account
│
├── NetworkAdmins (ネットワーク管理者)
│   └── Permission: NetworkAdmin → common-account
│
├── AppAdmins (アプリケーション管理者)
│   ├── Permission: AppAdmin → prod-app-account
│   └── Permission: AppAdmin → staging-account
│
├── Developers (開発者)
│   ├── Permission: Developer → staging-account
│   └── Permission: ReadOnly → prod-app-account
│
├── SecurityTeam (セキュリティチーム)
│   ├── Permission: SecurityAdmin → security-account
│   └── Permission: ReadOnly → 全アカウント
│
└── OperationsTeam (運用チーム)
    ├── Permission: OperationsAdmin → operations-account
    ├── Permission: ReadOnly → prod-app-account
    └── Permission: ReadOnly → staging-account
```

---

## 4. ネットワークアーキテクチャ

### 4.1 全体ネットワーク構成図

```
┌─────────────────────────────────────────────────────────────────┐
│                       庁舎（オンプレミス）                       │
│                                                                 │
│  ┌──────────────────────────────────────┐                     │
│  │  CGW (Customer Gateway)              │                     │
│  │  - 冗長化構成                         │                     │
│  └──────────────┬───────────────────────┘                     │
└─────────────────┼───────────────────────────────────────────────┘
                  │
                  │ AWS Direct Connect (1Gbps × 2回線 冗長化)
                  │
┌─────────────────▼───────────────────────────────────────────────┐
│              AWS Direct Connect Location                        │
│              (東京リージョン)                                     │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │
┌─────────────────▼───────────────────────────────────────────────┐
│              common-account (ap-northeast-1)                    │
│                                                                 │
│  ┌────────────────────────────────────────────────┐            │
│  │  Direct Connect Gateway                        │            │
│  │  - VIF (Virtual Interface) × 2 (冗長化)        │            │
│  └────────────────┬───────────────────────────────┘            │
│                   │                                             │
│  ┌────────────────▼───────────────────────────────┐            │
│  │  Transit Gateway (TGW)                         │            │
│  │  - ASN: 64512                                  │            │
│  │  - TGW Route Table: Prod, Staging, Shared     │            │
│  └────────────────┬───────────────────────────────┘            │
│                   │                                             │
│  ┌────────────────▼───────────────────────────────┐            │
│  │  VPC (共通サービス VPC)                         │            │
│  │  - CIDR: 10.0.0.0/16                           │            │
│  │                                                 │            │
│  │  ┌─────────────────────────────┐               │            │
│  │  │ AWS Network Firewall        │               │            │
│  │  │ - Stateful/Stateless Rules  │               │            │
│  │  │ - IPS/IDS機能               │               │            │
│  │  └─────────────────────────────┘               │            │
│  │                                                 │            │
│  │  ┌─────────────────────────────┐               │            │
│  │  │ Route 53 Resolver Endpoint  │               │            │
│  │  │ - Inbound/Outbound          │               │            │
│  │  └─────────────────────────────┘               │            │
│  └─────────────────────────────────────────────────┘            │
└─────────────────┬───────────────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼─────────┐  ┌──────▼────────┐
│ prod-app-account│  │staging-account│
│ (ap-northeast-1)│  │(ap-northeast-1)│
└─────────────────┘  └───────────────┘
```

### 4.2 VPC設計

#### 4.2.1 common-account VPC (共通サービスVPC)

| 項目 | 値 |
|-----|-----|
| VPC CIDR | 10.0.0.0/16 |
| AZ構成 | ap-northeast-1a, 1c, 1d (3-AZ) |
| サブネット構成 | Firewall Subnet, TGW Attachment Subnet |

**サブネット詳細:**

| サブネット名 | CIDR | AZ | 用途 |
|------------|------|----|----|
| firewall-subnet-1a | 10.0.1.0/24 | ap-northeast-1a | Network Firewall Endpoint |
| firewall-subnet-1c | 10.0.2.0/24 | ap-northeast-1c | Network Firewall Endpoint |
| firewall-subnet-1d | 10.0.3.0/24 | ap-northeast-1d | Network Firewall Endpoint |
| tgw-attachment-subnet-1a | 10.0.11.0/24 | ap-northeast-1a | Transit Gateway Attachment |
| tgw-attachment-subnet-1c | 10.0.12.0/24 | ap-northeast-1c | Transit Gateway Attachment |
| tgw-attachment-subnet-1d | 10.0.13.0/24 | ap-northeast-1d | Transit Gateway Attachment |
| resolver-subnet-1a | 10.0.21.0/24 | ap-northeast-1a | Route 53 Resolver Endpoint |
| resolver-subnet-1c | 10.0.22.0/24 | ap-northeast-1c | Route 53 Resolver Endpoint |

#### 4.2.2 prod-app-account VPC (本番アプリケーションVPC)

| 項目 | 値 |
|-----|-----|
| VPC CIDR | 10.1.0.0/16 |
| AZ構成 | ap-northeast-1a, 1c (Multi-AZ) |
| DNS Resolution | 有効 |
| DNS Hostnames | 有効 |

**サブネット詳細:**

| サブネット名 | CIDR | AZ | 用途 | インターネット接続 |
|------------|------|----|----|------------------|
| public-subnet-1a | 10.1.1.0/24 | ap-northeast-1a | ALB, NAT Gateway | あり (IGW経由) |
| public-subnet-1c | 10.1.2.0/24 | ap-northeast-1c | ALB, NAT Gateway | あり (IGW経由) |
| private-app-subnet-1a | 10.1.11.0/24 | ap-northeast-1a | ECS Fargate | なし (NAT経由) |
| private-app-subnet-1c | 10.1.12.0/24 | ap-northeast-1c | ECS Fargate | なし (NAT経由) |
| private-db-subnet-1a | 10.1.21.0/24 | ap-northeast-1a | RDS Primary | なし |
| private-db-subnet-1c | 10.1.22.0/24 | ap-northeast-1c | RDS Standby | なし |
| private-cache-subnet-1a | 10.1.31.0/24 | ap-northeast-1a | ElastiCache | なし |
| private-cache-subnet-1c | 10.1.32.0/24 | ap-northeast-1c | ElastiCache | なし |
| tgw-attachment-subnet-1a | 10.1.41.0/24 | ap-northeast-1a | TGW Attachment | なし |
| tgw-attachment-subnet-1c | 10.1.42.0/24 | ap-northeast-1c | TGW Attachment | なし |

#### 4.2.3 staging-account VPC (ステージングVPC)

| 項目 | 値 |
|-----|-----|
| VPC CIDR | 10.2.0.0/16 |
| AZ構成 | ap-northeast-1a, 1c (Multi-AZ) |
| DNS Resolution | 有効 |
| DNS Hostnames | 有効 |

**サブネット詳細:**

| サブネット名 | CIDR | AZ | 用途 | インターネット接続 |
|------------|------|----|----|------------------|
| public-subnet-1a | 10.2.1.0/24 | ap-northeast-1a | ALB, NAT Gateway | あり (IGW経由) |
| public-subnet-1c | 10.2.2.0/24 | ap-northeast-1c | ALB | あり (IGW経由) |
| private-app-subnet-1a | 10.2.11.0/24 | ap-northeast-1a | ECS Fargate (T系) | なし (NAT経由) |
| private-app-subnet-1c | 10.2.12.0/24 | ap-northeast-1c | ECS Fargate (T系) | なし (NAT経由) |
| private-db-subnet-1a | 10.2.21.0/24 | ap-northeast-1a | RDS (Single-AZ) | なし |
| private-db-subnet-1c | 10.2.22.0/24 | ap-northeast-1c | RDS Subnet Group用 | なし |
| tgw-attachment-subnet-1a | 10.2.41.0/24 | ap-northeast-1a | TGW Attachment | なし |
| tgw-attachment-subnet-1c | 10.2.42.0/24 | ap-northeast-1c | TGW Attachment | なし |

### 4.3 Transit Gateway設計

#### 4.3.1 Transit Gateway構成

| 項目 | 値 |
|-----|-----|
| 名前 | niigatacity-kaigo-tgw |
| ASN | 64512 |
| Default Route Table Association | 無効 |
| Default Route Table Propagation | 無効 |
| DNS Support | 有効 |
| VPN ECMP Support | 有効 |
| Multi-AZ | 有効 (ap-northeast-1a, 1c, 1d) |

#### 4.3.2 Transit Gateway Route Table

**Production Route Table:**

| 宛先CIDR | ターゲット | 説明 |
|---------|-----------|-----|
| 10.1.0.0/16 | prod-app-vpc-attachment | 本番VPC |
| 10.0.0.0/16 | common-vpc-attachment | 共通VPC (Firewall経由) |
| 192.168.0.0/16 | dx-gateway-attachment | オンプレミス (Direct Connect経由) |

**Staging Route Table:**

| 宛先CIDR | ターゲット | 説明 |
|---------|-----------|-----|
| 10.2.0.0/16 | staging-vpc-attachment | ステージングVPC |
| 10.0.0.0/16 | common-vpc-attachment | 共通VPC (Firewall経由) |
| 192.168.0.0/16 | dx-gateway-attachment | オンプレミス (Direct Connect経由) |

**Shared Route Table:**

| 宛先CIDR | ターゲット | 説明 |
|---------|-----------|-----|
| 10.1.0.0/16 | prod-app-vpc-attachment | 本番VPCへのルート |
| 10.2.0.0/16 | staging-vpc-attachment | ステージングVPCへのルート |
| 192.168.0.0/16 | dx-gateway-attachment | オンプレミスへのルート |

#### 4.3.3 VPC Attachment

| VPC | アカウント | Route Table | 説明 |
|-----|----------|-------------|-----|
| common-vpc | common-account | Shared | 共通サービスVPC |
| prod-app-vpc | prod-app-account | Production | 本番アプリケーションVPC |
| staging-vpc | staging-account | Staging | ステージングVPC |

### 4.4 Direct Connect設計

#### 4.4.1 接続構成

| 項目 | 値 |
|-----|-----|
| 接続タイプ | Dedicated Connection |
| 帯域幅 | 1Gbps × 2回線 (冗長化) |
| ロケーション | 東京 (複数拠点で冗長化) |
| VLAN | 100 (Primary), 200 (Secondary) |
| BGP ASN (AWS側) | 64512 |
| BGP ASN (Customer側) | 65000 |

#### 4.4.2 Virtual Interface構成

| VIF名 | タイプ | VLAN | 用途 | BGP Session |
|------|------|------|-----|------------|
| dx-vif-primary | Private VIF | 100 | 本番・ステージング共用 | 169.254.0.0/30 |
| dx-vif-secondary | Private VIF | 200 | バックアップ回線 | 169.254.0.4/30 |

#### 4.4.3 Direct Connect Gateway

| 項目 | 値 |
|-----|-----|
| 名前 | niigatacity-dx-gateway |
| ASN | 64512 (Transit Gatewayと同一) |
| Associated Transit Gateway | niigatacity-kaigo-tgw |
| Allowed Prefixes | 10.0.0.0/8, 192.168.0.0/16 |

### 4.5 Route 53設計

#### 4.5.1 ホストゾーン構成

**プライベートホストゾーン:**

| ホストゾーン名 | 関連VPC | 用途 |
|-------------|--------|-----|
| kaigo.niigata.local | prod-app-vpc, common-vpc | 本番環境内部DNS |
| kaigo-stg.niigata.local | staging-vpc, common-vpc | ステージング環境内部DNS |

**パブリックホストゾーン:**

| ホストゾーン名 | 用途 |
|-------------|-----|
| kaigo.niigata.jp (例) | 外部公開用ドメイン (CloudFront経由) |

#### 4.5.2 Route 53 Resolver

**Inbound Endpoint (オンプレミス → AWS):**

| 項目 | 値 |
|-----|-----|
| 配置サブネット | resolver-subnet-1a, resolver-subnet-1c |
| IP Address | 10.0.21.10, 10.0.22.10 |
| 用途 | オンプレミスからAWS内リソースの名前解決 |

**Outbound Endpoint (AWS → オンプレミス):**

| 項目 | 値 |
|-----|-----|
| 配置サブネット | resolver-subnet-1a, resolver-subnet-1c |
| 転送ルール | niigata.local → 192.168.1.53, 192.168.2.53 |
| 用途 | AWS内からオンプレミスリソースの名前解決 |

---

## 5. セキュリティアーキテクチャ

### 5.1 セキュリティ層構成

```
Layer 7 (Application) ─── WAF (CloudFront, ALB)
Layer 4-6 (Network)   ─── Network Firewall, Security Groups, NACLs
Layer 3 (Network)     ─── Transit Gateway, Route Tables
Identity & Access    ─── IAM Identity Center, IAM Policies, SCP
Data Protection      ─── KMS, S3 Encryption, RDS Encryption
Threat Detection     ─── GuardDuty, Security Hub, CloudWatch
Audit & Compliance   ─── CloudTrail, Config, AWS Audit Manager
```

### 5.2 AWS WAF設計

#### 5.2.1 WebACL構成

**CloudFront用WebACL (グローバル - us-east-1):**

| ルール名 | 優先度 | タイプ | アクション | 説明 |
|---------|--------|-------|----------|-----|
| AWS-AWSManagedRulesCommonRuleSet | 1 | Managed | Block | OWASP Top 10対策 |
| AWS-AWSManagedRulesKnownBadInputsRuleSet | 2 | Managed | Block | 既知の脆弱性攻撃対策 |
| AWS-AWSManagedRulesSQLiRuleSet | 3 | Managed | Block | SQLインジェクション対策 |
| RateLimitRule | 4 | Custom | Block | 2000 req/5min/IP |
| GeoBlockingRule | 5 | Custom | Block | 日本以外からのアクセス制限 |
| AllowedIPRule | 6 | Custom | Allow | 庁舎からの許可IP |

**ALB用WebACL (リージョナル - ap-northeast-1):**

| ルール名 | 優先度 | タイプ | アクション | 説明 |
|---------|--------|-------|----------|-----|
| AWS-AWSManagedRulesCommonRuleSet | 1 | Managed | Block | OWASP Top 10対策 |
| RateLimitRule | 2 | Custom | Block | 1000 req/5min/IP |
| IPWhitelistRule | 3 | Custom | Allow | CloudFrontのみ許可 |

#### 5.2.2 WAFログ設定

| 項目 | 値 |
|-----|-----|
| ログ送信先 | S3 Bucket (audit-account) |
| ログ保持期間 | 90日 (S3), 7日 (CloudWatch Logs) |
| サンプリングレート | 100% (全リクエストログ記録) |
| ログ形式 | JSON |

### 5.3 Network Firewall設計

#### 5.3.1 ファイアウォールポリシー

**Stateless Rules (優先度順):**

| 優先度 | ソース | 宛先 | プロトコル | アクション | 説明 |
|--------|-------|-----|----------|----------|-----|
| 1 | 192.168.0.0/16 | 10.0.0.0/8 | Any | Pass | オンプレミス → AWS |
| 2 | 10.1.0.0/16 | 192.168.0.0/16 | Any | Pass | 本番 → オンプレミス |
| 3 | 10.2.0.0/16 | 192.168.0.0/16 | Any | Pass | ステージング → オンプレミス |
| 100 | Any | Any | Any | Forward to Stateful | Statefulルールへ転送 |

**Stateful Rules:**

| ルールグループ | タイプ | 説明 |
|-------------|-------|-----|
| DomainFilteringRuleGroup | Domain List | 許可ドメインリスト (AWS API, GitHub, etc.) |
| ThreatIntelRuleGroup | Managed | AWS Threat Intelligence |
| IPSRuleGroup | Suricata | IPS/IDS機能 (Suricataルール) |
| CustomBlockRuleGroup | Custom | カスタムブロックルール |

#### 5.3.2 IPS/IDSルール (Suricata)

```suricata
# 例: SQLインジェクション検出
alert http $EXTERNAL_NET any -> $HOME_NET any (msg:"SQL Injection Attempt";
  flow:to_server,established; content:"union"; nocase; content:"select";
  nocase; classtype:web-application-attack; sid:1000001; rev:1;)

# 例: RCE攻撃検出
alert http $EXTERNAL_NET any -> $HOME_NET any (msg:"Remote Code Execution Attempt";
  flow:to_server,established; content:"eval("; nocase;
  classtype:web-application-attack; sid:1000002; rev:1;)
```

### 5.4 Security Groups設計

#### 5.4.1 prod-app-account Security Groups

**ALB Security Group (sg-alb-prod):**

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|------|----------|----------|-------|-----|
| Inbound | HTTPS | 443 | 0.0.0.0/0 | インターネットからHTTPS |
| Inbound | HTTP | 80 | 0.0.0.0/0 | HTTPからHTTPSへリダイレクト |
| Outbound | HTTP | 8080 | sg-ecs-prod | ECS Fargateへ転送 |

**ECS Fargate Security Group (sg-ecs-prod):**

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|------|----------|----------|-------|-----|
| Inbound | HTTP | 8080 | sg-alb-prod | ALBからのトラフィック |
| Outbound | PostgreSQL | 5432 | sg-rds-prod | RDSへの接続 |
| Outbound | Redis | 6379 | sg-cache-prod | ElastiCacheへの接続 |
| Outbound | HTTPS | 443 | 0.0.0.0/0 | 外部API呼び出し (NAT経由) |

**RDS Security Group (sg-rds-prod):**

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|------|----------|----------|-------|-----|
| Inbound | PostgreSQL | 5432 | sg-ecs-prod | ECS Fargateからの接続 |
| Inbound | PostgreSQL | 5432 | 192.168.0.0/16 | オンプレミスからの管理接続 |

**ElastiCache Security Group (sg-cache-prod):**

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|------|----------|----------|-------|-----|
| Inbound | Redis | 6379 | sg-ecs-prod | ECS Fargateからの接続 |

### 5.5 KMS暗号化戦略

#### 5.5.1 KMSキー構成

| キー名 | タイプ | 用途 | ローテーション | キーポリシー |
|-------|------|-----|------------|-----------|
| prod-rds-key | Customer Managed | RDS暗号化 | 有効 (年次) | RDSサービス、管理者 |
| prod-s3-key | Customer Managed | S3暗号化 | 有効 (年次) | S3サービス、管理者 |
| prod-ebs-key | Customer Managed | EBS暗号化 | 有効 (年次) | EC2サービス、管理者 |
| cloudtrail-key | Customer Managed | CloudTrail暗号化 | 有効 (年次) | CloudTrailサービス |
| backup-key | Customer Managed | バックアップ暗号化 | 有効 (年次) | Backupサービス、管理者 |

#### 5.5.2 キーポリシー例 (RDS用)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::555555555555:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow RDS to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "rds.ap-northeast-1.amazonaws.com"
        }
      }
    },
    {
      "Sid": "Allow CloudWatch Logs",
      "Effect": "Allow",
      "Principal": {
        "Service": "logs.ap-northeast-1.amazonaws.com"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
```

### 5.6 脅威検出とインシデント対応

#### 5.6.1 GuardDuty設定

| 項目 | 設定値 |
|-----|-------|
| 有効化範囲 | 全アカウント (Organizations統合) |
| 委任管理者 | security-account |
| 検出対象 | EC2, S3, IAM, EKS, Lambda, RDS |
| 通知設定 | EventBridge → SNS → Email/Slack |
| S3 Protection | 有効 |
| EKS Protection | 該当なし (ECS使用) |
| RDS Protection | 有効 |

#### 5.6.2 Security Hub設定

| 項目 | 設定値 |
|-----|-------|
| 有効化範囲 | 全アカウント |
| 集約先 | security-account |
| セキュリティ標準 | AWS Foundational Security Best Practices, CIS AWS Foundations Benchmark v1.4.0, PCI DSS v3.2.1 |
| 統合サービス | GuardDuty, Inspector, Macie, IAM Access Analyzer, Config |
| 自動修復 | Systems Manager Automationで一部自動修復 |

#### 5.6.3 インシデント対応フロー

```
GuardDuty検出
    │
    ├─ Critical/High ──> EventBridge ──> Lambda (Bedrock連携)
    │                                      │
    │                                      ├─ 一次調査実施
    │                                      ├─ 調査結果生成
    │                                      └─ SNS通知 (詳細付き)
    │                                          │
    │                                          ├─ Email (セキュリティチーム)
    │                                          └─ Slack (オンコール担当者)
    │
    └─ Medium/Low ──> EventBridge ──> SNS ──> Email (日次サマリー)
```

---

## 6. コンピューティングアーキテクチャ

### 6.1 ECS Fargate構成

#### 6.1.1 本番環境 (prod-app-account)

**ECSクラスター:**

| 項目 | 値 |
|-----|-----|
| クラスター名 | kaigo-prod-cluster |
| キャパシティプロバイダー | FARGATE, FARGATE_SPOT (80:20比率) |
| Container Insights | 有効 |
| 実行ロール | ecsTaskExecutionRole (ECR, CloudWatch Logs権限) |

**ECSサービス:**

| 項目 | 値 |
|-----|-----|
| サービス名 | kaigo-web-service |
| タスク定義 | kaigo-web-task:latest |
| 希望タスク数 | 2 (最小) |
| Auto Scaling | 有効 (2〜10タスク) |
| デプロイタイプ | Rolling Update |
| 配置戦略 | Spread (AZ分散) |
| ヘルスチェック猶予期間 | 60秒 |
| ロードバランサー | ALB (kaigo-prod-alb) |

**タスク定義:**

```json
{
  "family": "kaigo-web-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "2048",
  "memory": "4096",
  "executionRoleArn": "arn:aws:iam::555555555555:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::555555555555:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "kaigo-web",
      "image": "555555555555.dkr.ecr.ap-northeast-1.amazonaws.com/kaigo-web:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "ENV",
          "value": "production"
        },
        {
          "name": "DB_HOST",
          "value": "kaigo-prod-db.cluster-xxxxx.ap-northeast-1.rds.amazonaws.com"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/db/password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/kaigo-web-prod",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

#### 6.1.2 ステージング環境 (staging-account)

**ECSクラスター:**

| 項目 | 値 |
|-----|-----|
| クラスター名 | kaigo-staging-cluster |
| キャパシティプロバイダー | FARGATE (T系相当のリソース割り当て) |
| Container Insights | 有効 |

**ECSサービス:**

| 項目 | 値 |
|-----|-----|
| サービス名 | kaigo-web-service-staging |
| タスク定義 | kaigo-web-task-staging:latest |
| 希望タスク数 | 1 (最小) |
| Auto Scaling | 有効 (1〜3タスク) |
| CPU | 1024 (1 vCPU) |
| Memory | 2048 (2 GB) |

### 6.2 Application Load Balancer設計

#### 6.2.1 本番ALB (prod-app-account)

| 項目 | 値 |
|-----|-----|
| 名前 | kaigo-prod-alb |
| スキーム | Internet-facing |
| IP Address Type | IPv4 |
| サブネット | public-subnet-1a, public-subnet-1c |
| Security Group | sg-alb-prod |
| アクセスログ | 有効 (S3バケット: alb-logs-prod) |
| Idle Timeout | 60秒 |
| Deletion Protection | 有効 |

**リスナー設定:**

| プロトコル | ポート | デフォルトアクション | SSL/TLS証明書 |
|----------|--------|-----------------|--------------|
| HTTPS | 443 | Forward to Target Group | ACM証明書 (*.kaigo.niigata.jp) |
| HTTP | 80 | Redirect to HTTPS | - |

**ターゲットグループ:**

| 項目 | 値 |
|-----|-----|
| 名前 | kaigo-web-tg-prod |
| ターゲットタイプ | IP (Fargate) |
| プロトコル | HTTP |
| ポート | 8080 |
| VPC | prod-app-vpc |
| ヘルスチェックパス | /health |
| ヘルスチェック間隔 | 30秒 |
| 正常しきい値 | 2 |
| 異常しきい値 | 2 |
| タイムアウト | 5秒 |
| Deregistration Delay | 30秒 |
| Stickiness | 有効 (1時間) |

**リスナールール:**

| 優先度 | 条件 | アクション |
|--------|-----|----------|
| 1 | Path = /api/* | Forward to kaigo-api-tg-prod |
| 2 | Host = admin.kaigo.niigata.jp | Forward to kaigo-admin-tg-prod |
| Default | - | Forward to kaigo-web-tg-prod |

### 6.3 Auto Scaling設計

#### 6.3.1 ECS Service Auto Scaling

**本番環境スケーリングポリシー:**

| メトリクス | しきい値 | スケールアウト | スケールイン | クールダウン |
|----------|---------|------------|------------|-----------|
| CPU使用率 | 70% | +2タスク | -1タスク | 300秒 |
| メモリ使用率 | 80% | +2タスク | -1タスク | 300秒 |
| ALB Target Response Time | 500ms | +1タスク | -1タスク | 180秒 |
| ALB Target Connection Count | 1000 | +2タスク | - | 60秒 |

**ステージング環境スケーリングポリシー:**

| メトリクス | しきい値 | スケールアウト | スケールイン | クールダウン |
|----------|---------|------------|------------|-----------|
| CPU使用率 | 80% | +1タスク | -1タスク | 300秒 |

#### 6.3.2 スケジュールベーススケーリング

**本番環境:**

| スケジュール名 | 時刻 (JST) | 希望タスク数 | 最小タスク数 | 最大タスク数 |
|-------------|-----------|------------|------------|------------|
| morning-scale-up | 平日 08:00 | 4 | 4 | 10 |
| evening-scale-down | 平日 20:00 | 2 | 2 | 10 |
| weekend-scale-down | 土日 終日 | 2 | 2 | 6 |

---

## 7. データアーキテクチャ

### 7.1 RDS PostgreSQL設計

#### 7.1.1 本番環境 (prod-app-account)

**DBクラスター構成:**

| 項目 | 値 |
|-----|-----|
| エンジン | Amazon RDS for PostgreSQL 16.1 |
| インスタンスクラス | db.r6g.large (2 vCPU, 16 GB RAM) |
| Multi-AZ | 有効 (同期レプリケーション) |
| プライマリAZ | ap-northeast-1a |
| スタンバイAZ | ap-northeast-1c |
| ストレージタイプ | General Purpose SSD (gp3) |
| 割り当てストレージ | 500 GB |
| IOPS | 12,000 (プロビジョンド) |
| スループット | 500 MB/s |
| ストレージ自動拡張 | 有効 (最大 1000 GB) |
| 暗号化 | 有効 (KMS: prod-rds-key) |
| バックアップ保持期間 | 7日 |
| バックアップウィンドウ | 03:00-04:00 JST |
| メンテナンスウィンドウ | 日曜 04:00-05:00 JST |
| 自動マイナーバージョンアップグレード | 有効 |

**パラメータグループ設定:**

| パラメータ | 値 | 説明 |
|----------|----|----|
| max_connections | 500 | 最大接続数 |
| shared_buffers | 4GB | 共有バッファサイズ |
| effective_cache_size | 12GB | 有効キャッシュサイズ |
| work_mem | 32MB | ワークメモリ |
| maintenance_work_mem | 512MB | メンテナンス用メモリ |
| log_min_duration_statement | 1000 | 1秒以上のクエリをログ記録 |
| log_connections | on | 接続ログ記録 |
| log_disconnections | on | 切断ログ記録 |
| rds.force_ssl | 1 | SSL接続強制 |

**拡張機能:**

| 拡張機能 | バージョン | 用途 |
|---------|----------|-----|
| pg_stat_statements | 1.10 | クエリパフォーマンス分析 |
| pgaudit | 16 | 監査ログ |
| pg_cron | 1.5 | スケジュールジョブ |

#### 7.1.2 ステージング環境 (staging-account)

| 項目 | 値 |
|-----|-----|
| エンジン | Amazon RDS for PostgreSQL 16.1 |
| インスタンスクラス | db.t4g.medium (2 vCPU, 4 GB RAM) |
| Multi-AZ | 無効 (Single-AZ) |
| AZ | ap-northeast-1a |
| ストレージタイプ | General Purpose SSD (gp3) |
| 割り当てストレージ | 100 GB |
| 暗号化 | 有効 (KMS: staging-rds-key) |
| バックアップ保持期間 | 3日 |

#### 7.1.3 リードレプリカ戦略 (本番のみ)

| 項目 | 値 |
|-----|-----|
| リードレプリカ数 | 1 (レポート用) |
| インスタンスクラス | db.r6g.large |
| 配置AZ | ap-northeast-1d |
| レプリケーション方式 | 非同期レプリケーション |
| 昇格可能 | 有効 (DR用) |

### 7.2 ElastiCache Redis設計

#### 7.2.1 本番環境 (prod-app-account)

| 項目 | 値 |
|-----|-----|
| エンジン | Redis 7.0 |
| ノードタイプ | cache.r6g.large (2 vCPU, 13.07 GB RAM) |
| クラスターモード | 有効 (シャード数: 2) |
| レプリカ数/シャード | 1 (Multi-AZ) |
| 合計ノード数 | 4 (2シャード × 2ノード) |
| 自動フェイルオーバー | 有効 |
| 暗号化 (at rest) | 有効 (KMS) |
| 暗号化 (in transit) | 有効 (TLS) |
| Auth Token | 有効 |
| スナップショット保持期間 | 7日 |
| スナップショットウィンドウ | 03:00-04:00 JST |
| メンテナンスウィンドウ | 日曜 04:00-05:00 JST |

**パラメータグループ設定:**

| パラメータ | 値 | 説明 |
|----------|----|----|
| maxmemory-policy | allkeys-lru | メモリ満杯時のポリシー |
| timeout | 300 | アイドル接続タイムアウト (秒) |
| tcp-keepalive | 300 | TCP Keep-Alive (秒) |

#### 7.2.2 ステージング環境 (staging-account)

| 項目 | 値 |
|-----|-----|
| エンジン | Redis 7.0 |
| ノードタイプ | cache.t4g.small (2 vCPU, 1.37 GB RAM) |
| クラスターモード | 無効 |
| レプリカ数 | 0 (Single-AZ) |
| 暗号化 | 有効 |

### 7.3 S3バケット設計

#### 7.3.1 本番環境バケット (prod-app-account)

**アプリケーションデータバケット:**

| バケット名 | 用途 | ストレージクラス | ライフサイクルポリシー | バージョニング | レプリケーション |
|----------|-----|---------------|-------------------|-------------|--------------|
| kaigo-prod-documents | 申請書類保管 | Standard | 180日後→IA, 2年後→Glacier | 有効 | 大阪リージョンへCRR |
| kaigo-prod-uploads | アップロードファイル | Standard | 90日後→IA | 有効 | 有効 (大阪) |
| kaigo-prod-backups | DB/アプリバックアップ | Standard-IA | 30日後→Glacier | 有効 | 有効 (大阪) |
| kaigo-prod-logs | アプリケーションログ | Standard | 90日後→IA, 1年後→Glacier Deep Archive | 無効 | 無効 |
| alb-logs-prod | ALBアクセスログ | Standard | 30日後→IA, 90日後削除 | 無効 | 無効 |

**バケットポリシー (例: kaigo-prod-documents):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::kaigo-prod-documents/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::kaigo-prod-documents",
        "arn:aws:s3:::kaigo-prod-documents/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

#### 7.3.2 監査ログバケット (audit-account)

| バケット名 | 用途 | 保持期間 | レプリケーション |
|----------|-----|---------|--------------|
| cloudtrail-logs-audit | CloudTrailログ | 10年 (Glacier) | 有効 (大阪) |
| config-logs-audit | AWS Configスナップショット | 7年 | 有効 (大阪) |
| waf-logs-audit | WAFログ | 90日 | 無効 |
| vpc-flow-logs-audit | VPCフローログ | 90日 | 無効 |

### 7.4 データバックアップ戦略

#### 7.4.1 RDSバックアップ

| バックアップタイプ | 頻度 | 保持期間 | 保管先 |
|-----------------|------|---------|-------|
| 自動スナップショット | 日次 (03:00 JST) | 7日 | 東京リージョン |
| 手動スナップショット | 月次 (月初) | 1年 | 東京 + 大阪 (コピー) |
| PITR (Point-in-Time Recovery) | 継続的 | 7日 | 東京リージョン |

#### 7.4.2 AWS Backupによる統合バックアップ

**バックアッププラン:**

| リソース | 頻度 | 保持期間 | バックアップVault | Cross-Region Copy |
|---------|------|---------|-----------------|------------------|
| RDS | 日次 04:00 JST | 30日 | prod-backup-vault | 有効 (大阪, 7日保持) |
| EFS (将来対応) | 日次 04:00 JST | 30日 | prod-backup-vault | 有効 (大阪, 7日保持) |
| EBS (将来対応) | 日次 04:00 JST | 7日 | prod-backup-vault | 無効 |

---

## 8. 運用アーキテクチャ

### 8.1 監視戦略

#### 8.1.1 CloudWatch Metrics監視

**ECS Fargate監視メトリクス:**

| メトリクス | しきい値 (Warning) | しきい値 (Critical) | 評価期間 | アクション |
|----------|------------------|-------------------|---------|----------|
| CPUUtilization | 70% | 85% | 5分間の平均 | SNS通知, Auto Scaling |
| MemoryUtilization | 80% | 90% | 5分間の平均 | SNS通知, Auto Scaling |
| TaskCount | < 2 | < 1 | 1分間 | SNS通知, Lambda (再起動) |

**RDS監視メトリクス:**

| メトリクス | しきい値 (Warning) | しきい値 (Critical) | 評価期間 | アクション |
|----------|------------------|-------------------|---------|----------|
| CPUUtilization | 70% | 85% | 5分間の平均 | SNS通知 |
| FreeableMemory | < 2 GB | < 1 GB | 5分間の平均 | SNS通知, Bedrock調査 |
| DatabaseConnections | > 400 | > 450 | 5分間の平均 | SNS通知 |
| ReadLatency | > 10ms | > 20ms | 5分間の平均 | SNS通知 |
| WriteLatency | > 10ms | > 20ms | 5分間の平均 | SNS通知 |
| DiskQueueDepth | > 10 | > 20 | 5分間の平均 | SNS通知 |

**ALB監視メトリクス:**

| メトリクス | しきい値 (Warning) | しきい値 (Critical) | 評価期間 | アクション |
|----------|------------------|-------------------|---------|----------|
| TargetResponseTime | > 1秒 | > 3秒 | 5分間の平均 | SNS通知 |
| HTTPCode_Target_5XX_Count | > 10 | > 50 | 5分間 | SNS通知, Bedrock調査 |
| UnHealthyHostCount | > 0 | - | 2分間 | SNS通知 |
| RequestCount | > 10000 | - | 1分間 | SNS通知 (DDoS疑い) |

#### 8.1.2 CloudWatch Logs監視

**ログ収集対象:**

| ログソース | ロググループ | 保持期間 | サブスクリプションフィルター |
|----------|-----------|---------|------------------------|
| ECS Fargate | /ecs/kaigo-web-prod | 90日 | ERROR, WARN → Lambda (Bedrock) |
| RDS PostgreSQL | /aws/rds/cluster/kaigo-prod-db/postgresql | 30日 | ERROR → Lambda (Bedrock) |
| ALB | /aws/elasticloadbalancing/kaigo-prod-alb | 30日 | 5XX → Lambda |
| Lambda | /aws/lambda/bedrock-incident-analyzer | 30日 | ERROR → SNS |
| VPC Flow Logs | /aws/vpc/flowlogs/prod-app-vpc | 30日 | 異常トラフィック → Lambda |

**Logs Insights クエリ例:**

```cloudwatch
# ECS Fargateエラー分析
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)
| sort @timestamp desc
| limit 100

# RDS遅いクエリ分析
fields @timestamp, @message
| filter @message like /duration:/
| parse @message /duration: (?<duration>\d+\.\d+) ms/
| filter duration > 1000
| sort duration desc
| limit 20
```

#### 8.1.3 統合ダッシュボード (operations-account)

**本番環境監視ダッシュボード (CloudWatch Dashboard):**

```
┌─────────────────────────────────────────────────────────────┐
│  新潟市介護保険システム - 本番環境監視ダッシュボード          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [システム全体ステータス]                                     │
│  ● ECS Service: RUNNING (4/4 tasks)                        │
│  ● RDS Cluster: AVAILABLE (Primary: 1a, Standby: 1c)      │
│  ● ALB: ACTIVE (Healthy targets: 4/4)                     │
│  ● ElastiCache: AVAILABLE (4/4 nodes)                     │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [パフォーマンスメトリクス]                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │ECS CPU   │  │ECS Memory│  │ALB       │               │
│  │45%       │  │62%       │  │Response  │               │
│  │          │  │          │  │時間: 250ms│               │
│  └──────────┘  └──────────┘  └──────────┘               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │RDS CPU   │  │RDS       │  │RDS       │               │
│  │35%       │  │Connection│  │Read      │               │
│  │          │  │: 85      │  │Latency:  │               │
│  │          │  │          │  │5ms       │               │
│  └──────────┘  └──────────┘  └──────────┘               │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [エラー・警告]                                              │
│  ⚠ 過去1時間のエラー: 3件                                   │
│  - 14:23 RDS Slow Query (2.5秒)                           │
│  - 14:15 ECS Task Restart (OOM)                           │
│  - 13:58 ALB 5XX Error (502)                              │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [トラフィック]                                              │
│  現在のリクエスト数: 1,250 req/min                           │
│  [グラフ: 過去24時間のリクエスト数推移]                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Bedrock活用の運用自動化

#### 8.2.1 アーキテクチャ

```
CloudWatch Alarm / Logs (ERROR検出)
    │
    └──> EventBridge Rule
            │
            └──> Lambda (bedrock-incident-analyzer)
                    │
                    ├── CloudWatch Logs Insights APIで関連ログ収集
                    ├── CloudWatch Metrics APIでメトリクス取得
                    ├── RDS Performance Insightsでクエリ分析
                    │
                    └──> Amazon Bedrock (Claude 3.5 Sonnet)
                            │
                            ├── ログ分析
                            ├── 原因推定
                            ├── 影響範囲評価
                            └── 推奨対応策生成
                                │
                                └──> SNS (調査結果通知)
                                        │
                                        ├── Email (運用チーム)
                                        └── Slack (オンコール担当者)
```

#### 8.2.2 Lambda関数設計 (bedrock-incident-analyzer)

**関数仕様:**

| 項目 | 値 |
|-----|-----|
| ランタイム | Python 3.12 |
| メモリ | 512 MB |
| タイムアウト | 5分 |
| 環境変数 | BEDROCK_MODEL_ID=anthropic.claude-3-5-sonnet-20241022-v2:0 |
| IAMロール | CloudWatch Logs読み取り, Bedrock InvokeModel, SNS Publish |
| 同時実行数 | 予約済み: 10 |

**プロンプトテンプレート:**

```python
INCIDENT_ANALYSIS_PROMPT = """
あなたはAWSシステムの運用エンジニアです。以下のインシデント情報を分析し、調査結果を報告してください。

## インシデント情報
- **発生時刻**: {timestamp}
- **アラーム名**: {alarm_name}
- **リソース**: {resource_type} - {resource_id}
- **メトリクス**: {metric_name} = {metric_value}

## 関連ログ (直近30分)
```
{logs}
```

## 関連メトリクス (直近1時間)
```
{metrics}
```

## RDS Performance Insights (該当する場合)
```
{performance_insights}
```

## 分析タスク
以下の項目について、運用チームが即座にアクションできる形で回答してください:

1. **根本原因の推定**
   - 何が問題を引き起こしたか
   - 技術的な原因 (コード、設定、リソース不足等)

2. **影響範囲の評価**
   - ユーザーへの影響 (High/Medium/Low)
   - 影響を受けているコンポーネント

3. **即時対応策**
   - 今すぐ実行すべきアクション (3ステップ以内)

4. **恒久対策**
   - 再発防止のための長期的な対策

5. **エスカレーション要否**
   - オンコール担当者への即時エスカレーションが必要か (Yes/No)
   - 理由

回答は簡潔に、技術的に正確に、運用担当者がすぐに理解できる形式でお願いします。
"""
```

**出力例:**

```
【インシデント自動分析レポート】

発生時刻: 2025-11-04 14:23:45 JST
アラーム: RDS-High-CPU-Utilization
リソース: kaigo-prod-db (RDS PostgreSQL)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. 根本原因の推定
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【推定原因】
- 14:20頃から大量の全テーブルスキャンクエリが実行されている
- users テーブルに対する WHERE 句なしの SELECT が多数実行
- クエリ実行元: ECSタスク eni-0a1b2c3d4e5f6

【技術的詳細】
- 平均クエリ実行時間: 2.5秒 (通常の50倍)
- テーブルサイズ: users (500万レコード)
- インデックス未使用 (Seq Scan)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. 影響範囲の評価
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【ユーザー影響】Medium
- 画面表示遅延: 通常500ms → 現在3秒
- 一部ユーザーでタイムアウトエラー発生の可能性

【影響コンポーネント】
- ECS Fargateアプリケーション (応答遅延)
- RDS (CPU 85%使用、接続数上昇)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. 即時対応策
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【今すぐ実行】
1. 問題のクエリを特定し、該当するECSタスクを再起動
   ```
   aws ecs list-tasks --cluster kaigo-prod-cluster
   aws ecs stop-task --task <task-id>
   ```

2. RDS Performance Insightsで実行中の遅いクエリを確認
   - usersテーブルへのクエリに WHERE 句が含まれているか確認

3. アプリケーションログで該当APIエンドポイントを特定
   ```
   aws logs filter-log-events --log-group-name /ecs/kaigo-web-prod \
     --start-time $(date -u -d '30 minutes ago' +%s)000 \
     --filter-pattern "users"
   ```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. 恒久対策
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. コードレビュー: 該当APIエンドポイントのクエリ最適化
   - WHERE句の追加、LIMIT句の使用
   - ページネーション実装

2. インデックス追加: usersテーブルの頻繁に検索されるカラム
   - CREATE INDEX ON users(user_id, status);

3. Slow Query Logの自動アラート設定
   - 1秒以上のクエリをCloudWatch Logsに記録し、Lambdaで検知

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. エスカレーション要否
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

【エスカレーション】No (現時点では不要)

【理由】
- ユーザー影響はMedium (サービス停止ではない)
- 即時対応策で解決可能
- 営業時間内であれば通常対応で問題なし

ただし、以下の場合はエスカレーション推奨:
- RDS CPU使用率が95%を超えた場合
- 5XX エラーが毎分100件を超えた場合
- 対応後も30分以内に改善しない場合

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 8.2.3 Bedrock使用量とコスト見積もり

| 項目 | 値 |
|-----|-----|
| モデル | Claude 3.5 Sonnet v2 |
| 平均入力トークン | 8,000トークン (ログ+メトリクス) |
| 平均出力トークン | 1,500トークン (分析レポート) |
| 想定インシデント数 | 50件/月 |
| 入力コスト | $3/MTok × 0.008 MTok × 50 = $1.20/月 |
| 出力コスト | $15/MTok × 0.0015 MTok × 50 = $1.13/月 |
| **合計コスト** | **約$2.33/月 (約¥330/月)** |

### 8.3 ログ集約とアーカイブ

#### 8.3.1 ログ集約アーキテクチャ (operations-account)

```
各アカウントのCloudWatch Logs
    │
    └──> CloudWatch Logs Subscription Filter
            │
            └──> Kinesis Data Firehose
                    │
                    ├─ (変換) Lambda (ログ整形・マスキング)
                    │
                    └──> S3 Bucket (operations-account/centralized-logs)
                            │
                            ├─ Standard (30日)
                            ├─ Standard-IA (31-90日)
                            └─ Glacier (91日以降)
```

#### 8.3.2 ログ分析 (Amazon Athena)

**Athenaテーブル定義:**

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS prod_ecs_logs (
  timestamp STRING,
  log_level STRING,
  message STRING,
  request_id STRING,
  user_id STRING,
  endpoint STRING,
  status_code INT,
  response_time DOUBLE
)
PARTITIONED BY (year STRING, month STRING, day STRING)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://centralized-logs-ops/prod/ecs-logs/'
TBLPROPERTIES ('projection.enabled'='true');
```

**サンプルクエリ:**

```sql
-- 過去7日間のエラー集計
SELECT
  date_trunc('hour', from_iso8601_timestamp(timestamp)) as hour,
  log_level,
  COUNT(*) as error_count
FROM prod_ecs_logs
WHERE year||month||day >= date_format(current_date - interval '7' day, '%Y%m%d')
  AND log_level IN ('ERROR', 'CRITICAL')
GROUP BY 1, 2
ORDER BY 1 DESC;

-- 遅いAPIエンドポイント分析
SELECT
  endpoint,
  AVG(response_time) as avg_response_time,
  MAX(response_time) as max_response_time,
  COUNT(*) as request_count
FROM prod_ecs_logs
WHERE year||month||day = date_format(current_date, '%Y%m%d')
  AND response_time > 1.0
GROUP BY endpoint
ORDER BY avg_response_time DESC
LIMIT 20;
```

---

## 9. ディザスタリカバリ戦略

### 9.1 DR方針

| 項目 | 値 |
|-----|-----|
| RTO (Recovery Time Objective) | 24時間 |
| RPO (Recovery Point Objective) | 24時間 |
| DR戦略 | Warm Standby (大阪リージョン) |
| フェイルオーバー方式 | 手動フェイルオーバー (運用判断後実施) |
| 定期訓練 | 年2回 (6月, 12月) |

### 9.2 DRサイト構成 (ap-northeast-3: 大阪)

#### 9.2.1 リソース構成

| リソース | 東京 (Primary) | 大阪 (DR) | 平常時のDRサイト状態 |
|---------|--------------|---------|-------------------|
| VPC | 10.1.0.0/16 | 10.3.0.0/16 | 構築済み (常時稼働) |
| ECS Fargate | 4タスク | 1タスク | 最小構成で稼働 |
| RDS | db.r6g.large Multi-AZ | db.r6g.large Single-AZ | Cross-Region Read Replica |
| ElastiCache | 4ノード | 2ノード | なし (フェイルオーバー時に構築) |
| S3 | 各バケット | レプリカバケット | Cross-Region Replication有効 |
| Route 53 | プライマリレコード | セカンダリレコード | ヘルスチェック監視 |

#### 9.2.2 DR VPC設計 (ap-northeast-3)

| サブネット名 | CIDR | AZ | 用途 |
|------------|------|----|----|
| public-subnet-3a | 10.3.1.0/24 | ap-northeast-3a | ALB |
| public-subnet-3b | 10.3.2.0/24 | ap-northeast-3b | ALB |
| private-app-subnet-3a | 10.3.11.0/24 | ap-northeast-3a | ECS Fargate |
| private-app-subnet-3b | 10.3.12.0/24 | ap-northeast-3b | ECS Fargate |
| private-db-subnet-3a | 10.3.21.0/24 | ap-northeast-3a | RDS Read Replica |
| private-db-subnet-3b | 10.3.22.0/24 | ap-northeast-3b | RDS Subnet Group用 |

### 9.3 フェイルオーバー手順

#### 9.3.1 フェイルオーバートリガー

以下の条件を満たした場合、フェイルオーバーを検討：

1. 東京リージョンの広域障害 (AWS公式発表あり)
2. RTO (24時間) 以内に復旧不可能と判断
3. ビジネス影響が重大 (Critical)

#### 9.3.2 フェイルオーバー手順 (概要)

| ステップ | 作業内容 | 実施者 | 所要時間 |
|---------|---------|-------|---------|
| 1. 意思決定 | フェイルオーバー実施の最終承認 | システム管理者 | 30分 |
| 2. 通知 | 関係者への障害通知・DR開始通知 | 運用チーム | 15分 |
| 3. RDS昇格 | Read Replicaを独立DBに昇格 | DBA | 15分 |
| 4. ECS拡張 | DRサイトのECSタスク数を増加 (1→4) | 運用チーム | 10分 |
| 5. ElastiCache構築 | キャッシュクラスター作成 | 運用チーム | 30分 |
| 6. DNS切り替え | Route 53レコード更新 (TTL待機) | ネットワーク管理者 | 10分 (+TTL 60秒) |
| 7. 動作確認 | DRサイトでの疎通確認 | 運用チーム | 30分 |
| 8. 監視強化 | DRサイトの監視強化 | 運用チーム | 15分 |
| **合計** | | | **約2時間35分** |

#### 9.3.3 フェイルバック手順 (概要)

東京リージョン復旧後のフェイルバック：

| ステップ | 作業内容 | 実施者 | 所要時間 |
|---------|---------|-------|---------|
| 1. 東京サイト復旧確認 | インフラ・アプリケーション正常性確認 | 運用チーム | 2時間 |
| 2. データ同期 | 大阪→東京へのデータ同期 (DMS使用) | DBA | 4時間 |
| 3. 東京サイト起動 | ECS, RDS, ElastiCache起動 | 運用チーム | 1時間 |
| 4. DNS切り戻し | Route 53レコード更新 | ネットワーク管理者 | 10分 |
| 5. 動作確認 | 東京サイトでの疎通確認 | 運用チーム | 1時間 |
| 6. 大阪サイト縮退 | DRサイトをWarm Standby状態に戻す | 運用チーム | 30分 |
| **合計** | | | **約8時間40分** |

### 9.4 バックアップ戦略 (詳細)

#### 9.4.1 RDSバックアップ

| バックアップタイプ | 実施タイミング | 保持期間 | 保管場所 | 暗号化 |
|-----------------|-------------|---------|---------|-------|
| 自動スナップショット | 毎日03:00 JST | 7日 | 東京リージョン | KMS (prod-rds-key) |
| 手動スナップショット | 月初 (1日) | 365日 | 東京 + 大阪 (コピー) | KMS (prod-rds-key) |
| クロスリージョンバックアップ | 毎日 (自動スナップショット後) | 7日 | 大阪リージョン | KMS (dr-rds-key) |

#### 9.4.2 S3バックアップ (Cross-Region Replication)

| ソースバケット (東京) | レプリカバケット (大阪) | レプリケーションルール | 削除マーカー複製 |
|-------------------|-------------------|-------------------|---------------|
| kaigo-prod-documents | kaigo-prod-documents-dr | 全オブジェクト | 有効 |
| kaigo-prod-uploads | kaigo-prod-uploads-dr | 全オブジェクト | 有効 |
| kaigo-prod-backups | kaigo-prod-backups-dr | 全オブジェクト | 有効 |

---

## 10. コスト最適化戦略

### 10.1 コスト見積もり (月額)

#### 10.1.1 本番環境 (prod-app-account)

| サービス | リソース | 数量 | 単価 | 月額コスト (USD) |
|---------|---------|-----|------|----------------|
| ECS Fargate | 2 vCPU, 4 GB | 平均4タスク × 730h | $0.04992/h | $145.65 |
| RDS PostgreSQL | db.r6g.large Multi-AZ | 1インスタンス | $0.584/h × 2 (Multi-AZ) | $852.32 |
| RDS Storage | gp3 500 GB | 500 GB × 2 (Multi-AZ) | $0.138/GB | $138.00 |
| RDS Backup | スナップショット | 500 GB | $0.095/GB | $47.50 |
| ElastiCache Redis | cache.r6g.large × 4 | 4ノード | $0.304/h × 4 | $887.68 |
| ALB | 1 ALB | 730h + 1000 LCU | $0.0225/h + $0.008/LCU | $24.43 |
| NAT Gateway | 2 NAT Gateways | 2 × 730h + 100 GB | $0.062/h × 2 + $0.062/GB | $96.64 |
| S3 | Standard 1 TB | 1024 GB | $0.025/GB | $25.60 |
| CloudFront | 1 TB転送 | 1024 GB | $0.114/GB | $116.74 |
| Direct Connect | 1 Gbps × 2 | 2ポート | $0.30/h × 2 | $438.00 |
| Transit Gateway | Attachments + Data | 3 Attachments + 1 TB | $0.07/h × 3 + $0.02/GB | $173.76 |
| Network Firewall | 2 AZ | 2 Endpoints × 730h | $0.395/h × 2 | $576.70 |
| Route 53 | 2 Hosted Zones | 2 Zones + 100M queries | $0.50/zone + $0.40/M | $41.00 |
| KMS | 5 Keys | 5 Keys + 10k requests | $1/key + $0.03/10k | $5.03 |
| CloudWatch Logs | 100 GB | 100 GB ingestion + storage | $0.50/GB + $0.03/GB | $53.00 |
| CloudWatch Metrics | Custom Metrics | 200 metrics | $0.30/metric | $60.00 |
| GuardDuty | イベント分析 | 5M CloudTrail + 100 GB VPC Flow | 変動 | $35.00 |
| Security Hub | Findings | 100k findings | $0.0010/finding | $100.00 |
| **本番環境小計** | | | | **$3,817.05** |

#### 10.1.2 ステージング環境 (staging-account)

| サービス | リソース | 数量 | 単価 | 月額コスト (USD) |
|---------|---------|-----|------|----------------|
| ECS Fargate | 1 vCPU, 2 GB | 平均1タスク × 730h | $0.02496/h | $18.22 |
| RDS PostgreSQL | db.t4g.medium Single-AZ | 1インスタンス | $0.082/h | $59.86 |
| RDS Storage | gp3 100 GB | 100 GB | $0.138/GB | $13.80 |
| ALB | 1 ALB | 730h + 100 LCU | $0.0225/h + $0.008/LCU | $17.23 |
| NAT Gateway | 1 NAT Gateway | 730h + 10 GB | $0.062/h + $0.062/GB | $45.88 |
| S3 | Standard 100 GB | 100 GB | $0.025/GB | $2.50 |
| CloudWatch Logs | 10 GB | 10 GB | $0.53/GB | $5.30 |
| **ステージング環境小計** | | | | **$162.79** |

#### 10.1.3 共通・運用アカウント (common-account, operations-account)

| サービス | 月額コスト (USD) |
|---------|----------------|
| common-account (VPC, TGW等) | $150.00 |
| operations-account (監視、Lambda等) | $50.00 |
| audit-account (ログ保管) | $30.00 |
| security-account (Security Hub集約等) | $20.00 |
| **共通・運用小計** | **$250.00** |

#### 10.1.4 総コスト

| 環境 | 月額コスト (USD) | 月額コスト (JPY, @¥140) |
|-----|----------------|---------------------|
| 本番環境 | $3,817.05 | ¥534,387 |
| ステージング環境 | $162.79 | ¥22,790 |
| 共通・運用 | $250.00 | ¥35,000 |
| **合計** | **$4,229.84** | **¥592,177** |

### 10.2 コスト削減施策

#### 10.2.1 予約購入によるコスト削減

**Savings Plans:**

| リソース | 購入タイプ | コミットメント | 削減率 | 年間削減額 (USD) |
|---------|----------|-------------|-------|----------------|
| ECS Fargate | Compute Savings Plan 1年 | $100/月 | 17% | $204 |
| RDS | RDS Reserved Instance 1年 | db.r6g.large Multi-AZ | 40% | $4,095 |
| ElastiCache | Reserved Node 1年 | cache.r6g.large × 4 | 35% | $3,728 |
| **削減合計** | | | | **$8,027/年** |

#### 10.2.2 リソース最適化施策

| 施策 | 対象 | 削減効果 | 実施時期 |
|-----|------|---------|---------|
| ECS Fargate Spot | 本番のバッチ処理 | 20%減 | Phase 2 |
| RDS Auto Scaling Storage | 本番RDS | ストレージコスト10%減 | 即時 |
| S3 Intelligent-Tiering | 全バケット | ストレージコスト30%減 | 即時 |
| CloudWatch Logs保持期間最適化 | 全ロググループ | ログコスト20%減 | 即時 |
| NAT Gateway統合 | ステージング | NAT Gateway 1個削減 ($45/月) | 即時 |

#### 10.2.3 コスト監視とアラート

**Cost Anomaly Detection:**

| 項目 | 設定値 |
|-----|-------|
| 検出対象 | 全アカウント (Organizations統合) |
| しきい値 | 月額予算の10%を超える異常 |
| 通知先 | SNS → Email (財務担当者) |
| 監視頻度 | 日次 |

**Budgets:**

| 予算名 | 対象アカウント | 月額予算 | アラートしきい値 |
|-------|-------------|---------|---------------|
| prod-monthly-budget | prod-app-account | $4,000 | 80%, 100%, 120% |
| staging-monthly-budget | staging-account | $200 | 80%, 100% |
| all-accounts-budget | 全アカウント | $5,000 | 90%, 100% |

---

## 変更履歴

| バージョン | 日付 | 変更内容 | 作成者 |
|----------|------|---------|-------|
| 1.0.0 | 2025-11-04 | 初版作成 | Claude |

---

## 承認

| 役割 | 氏名 | 承認日 | 署名 |
|-----|------|-------|-----|
| プロジェクトマネージャー | | | |
| インフラストラクチャアーキテクト | | | |
| セキュリティ責任者 | | | |
| 運用責任者 | | | |

---

**次のドキュメント:** [AWS詳細設計書](../detailed/01_aws_detailed_design.md)
