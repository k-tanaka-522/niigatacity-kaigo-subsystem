# アカウント設計書

## アカウント構成概要

### 基本方針

- **GCAS準拠**: 政府情報システムのセキュリティガイドラインに準拠
- **責務分離**: ネットワーク/ログとアプリケーションの分離
- **環境分離**: 本番環境とステージング環境の完全分離
- **爆発半径の最小化**: 障害・セキュリティ侵害の影響範囲を限定

### アカウント構成

```
管理アカウント
├── 本番環境 OU
│   ├── 本番共通系アカウント
│   └── 本番アプリ系アカウント
└── ステージング環境 OU
    ├── ステージング共通系アカウント
    └── ステージングアプリ系アカウント
```

---

## アカウント詳細

### 1. 管理アカウント（Root Account）

| 項目 | 内容 |
|------|------|
| アカウントID | （プロジェクト開始時に決定） |
| 用途 | AWS Organizations管理、請求管理 |
| デプロイするリソース | なし（管理専用） |
| アクセス権限 | 管理者のみ（最小限） |

#### 責務

- AWS Organizationsの管理
- SCP（Service Control Policies）の管理
- 一括請求（Consolidated Billing）
- アカウント作成・削除

#### セキュリティ要件

- **MFA必須**: すべてのIAMユーザーでMFA有効化
- **ルートユーザーアクセス制限**: 通常運用ではルートユーザーを使用しない
- **CloudTrail有効化**: 管理アカウントのAPI操作を記録

---

### 2. 本番共通系アカウント（Production Common Account）

| 項目 | 内容 |
|------|------|
| アカウント名 | niigata-kaigo-prod-common |
| 用途 | ネットワークインフラ、ログ集約、監査 |
| VPC CIDR | - |
| リージョン | ap-northeast-1 |

#### デプロイするリソース

**ネットワーク**
- AWS Transit Gateway
- Direct Connect Gateway
- Direct Connect Virtual Interface

**ログ・監査**
- CloudWatch Logs（ログ集約）
- CloudTrail（全アカウントのログ）
- AWS Config（全アカウントの構成履歴）
- S3バケット（ログ保管用）

**セキュリティ**
- GuardDuty（脅威検知）
- Security Hub（セキュリティ統合管理）

#### 責務

- ネットワークインフラの管理
- ログの集約・長期保管
- 監査ログの管理
- セキュリティサービスの一元管理

#### アクセス権限

- **ネットワーク管理者**: Transit Gateway、Direct Connectの管理
- **監査担当者**: CloudTrail、AWS Configの参照（読み取り専用）
- **セキュリティ担当者**: GuardDuty、Security Hubの管理

---

### 3. 本番アプリ系アカウント（Production Application Account）

| 項目 | 内容 |
|------|------|
| アカウント名 | niigata-kaigo-prod-app |
| 用途 | アプリケーションリソース |
| VPC CIDR | 10.1.0.0/16 |
| リージョン | ap-northeast-1 |

#### デプロイするリソース

**ネットワーク**
- VPC（10.1.0.0/16）
- Subnets（Public、Private App、Private DB、Private Cache）
- Internet Gateway
- NAT Gateway（2AZ）
- Security Groups
- Network ACLs

**コンピューティング**
- ECS Cluster
- ECS Services
- ECS Task Definitions
- ECR（コンテナレジストリ）
- Application Load Balancer

**データベース・キャッシュ**
- RDS MySQL（Multi-AZ）
- ElastiCache Redis

**ストレージ・CDN**
- S3バケット（ドキュメント保管）
- CloudFront

**セキュリティ**
- AWS WAF
- Cognito User Pool
- KMS（暗号化キー）

**監視**
- CloudWatch Alarms
- SNS（アラート通知）

#### 責務

- アプリケーションの実行環境
- アプリケーションデータの保管
- アプリケーション固有の監視

#### アクセス権限

- **開発者**: ECS、RDS、S3等の管理（変更可能）
- **運用担当者**: ECS、CloudWatch等の管理（デプロイ、監視）
- **読み取り専用**: 監査担当者（参照のみ）

---

### 4. ステージング共通系アカウント（Staging Common Account）

| 項目 | 内容 |
|------|------|
| アカウント名 | niigata-kaigo-stg-common |
| 用途 | ネットワークインフラ、ログ集約（ステージング） |
| VPC CIDR | - |
| リージョン | ap-northeast-1 |

#### デプロイするリソース

**ネットワーク**
- Transit Gateway Attachment（本番共通系のTransit Gatewayに接続）

**ログ・監査**
- CloudWatch Logs（ログ集約、短期保管）
- CloudTrail（ステージング環境のログ）

#### 責務

- ステージング環境のネットワーク管理
- ステージング環境のログ集約（短期保管）

#### アクセス権限

- **開発者**: ネットワーク、ログの参照
- **ネットワーク管理者**: Transit Gatewayの管理

---

### 5. ステージングアプリ系アカウント（Staging Application Account）

| 項目 | 内容 |
|------|------|
| アカウント名 | niigata-kaigo-stg-app |
| 用途 | アプリケーションリソース（ステージング） |
| VPC CIDR | 10.2.0.0/16 |
| リージョン | ap-northeast-1 |

#### デプロイするリソース

**ネットワーク**
- VPC（10.2.0.0/16）
- Subnets（Public、Private App、Private DB）
- Internet Gateway
- NAT Gateway（1AZ）
- Security Groups
- Network ACLs

**コンピューティング**
- ECS Cluster
- ECS Services（T系）
- ECS Task Definitions
- ECR
- Application Load Balancer

**データベース・キャッシュ**
- RDS MySQL（Single-AZ、T系）
- ElastiCache Redis（Small）

**ストレージ・CDN**
- S3バケット（テストデータ）
- CloudFront（オプション）

**セキュリティ**
- AWS WAF
- Cognito User Pool
- KMS

**監視**
- CloudWatch Alarms
- SNS

#### 責務

- アプリケーションの検証環境
- テストデータの保管

#### アクセス権限

- **開発者**: 全リソースの管理（変更可能）
- **QA担当者**: 参照、テスト実行

---

## アカウント間接続

### Transit Gateway による接続

```
本番共通系アカウント
  └── Transit Gateway（ハブ）
        ├── 本番アプリ系VPC（10.1.0.0/16）
        ├── ステージング共通系アカウント
        │     └── ステージングアプリ系VPC（10.2.0.0/16）
        └── Direct Connect Gateway
              └── 新潟市庁舎
```

### ルーティング

| 送信元 | 宛先 | 経路 |
|--------|------|------|
| 本番アプリ系VPC | 庁舎（192.168.0.0/16） | Transit Gateway → Direct Connect |
| ステージングアプリ系VPC | 庁舎（192.168.0.0/16） | Transit Gateway → Direct Connect |
| 庁舎 | 本番アプリ系VPC（10.1.0.0/16） | Direct Connect → Transit Gateway |
| 庁舎 | ステージングアプリ系VPC（10.2.0.0/16） | Direct Connect → Transit Gateway |

**重要**: 本番アプリ系VPC ⇔ ステージングアプリ系VPC の直接通信は**禁止**（Transit Gatewayルートテーブルで制御）

---

## SCP（Service Control Policies）

### 全アカウント共通のSCP

**deny-root-account.json**（ルートユーザーの使用制限）
- ルートユーザーでのAPI操作を禁止（緊急時を除く）

**require-mfa.json**（MFA必須）
- MFAが有効でない場合、API操作を禁止

**deny-region-outside-tokyo-osaka.json**（リージョン制限）
- 東京リージョン（ap-northeast-1）と大阪リージョン（ap-northeast-3）以外のリソース作成を禁止

### 本番環境OU のSCP

**deny-ebs-unencrypted.json**（EBS暗号化必須）
- 暗号化されていないEBSボリュームの作成を禁止

**deny-s3-public-access.json**（S3パブリックアクセス禁止）
- S3バケットのパブリックアクセスを禁止

### ステージング環境OU のSCP

本番環境と同等のSCPを適用

---

## IAM ロール

### クロスアカウントアクセス

**開発者ロール**（ステージングアプリ系 → 本番アプリ系）
- 本番環境への読み取り専用アクセス（トラブルシューティング用）
- AssumeRole で切り替え

**監査担当者ロール**（管理アカウント → 全アカウント）
- CloudTrail、AWS Config、CloudWatch Logs の読み取り専用アクセス
- AssumeRole で全アカウントを監査

---

## アカウント作成手順

### 1. 管理アカウントの作成

```bash
# AWS Organizations を有効化
aws organizations create-organization --feature-set ALL
```

### 2. OU（Organizational Unit）の作成

```bash
# 本番環境 OU
aws organizations create-organizational-unit \
  --parent-id r-xxxx \
  --name "Production"

# ステージング環境 OU
aws organizations create-organizational-unit \
  --parent-id r-xxxx \
  --name "Staging"
```

### 3. アカウントの作成

```bash
# 本番共通系アカウント
aws organizations create-account \
  --email niigata-kaigo-prod-common@example.com \
  --account-name "niigata-kaigo-prod-common"

# 本番アプリ系アカウント
aws organizations create-account \
  --email niigata-kaigo-prod-app@example.com \
  --account-name "niigata-kaigo-prod-app"

# ステージング共通系アカウント
aws organizations create-account \
  --email niigata-kaigo-stg-common@example.com \
  --account-name "niigata-kaigo-stg-common"

# ステージングアプリ系アカウント
aws organizations create-account \
  --email niigata-kaigo-stg-app@example.com \
  --account-name "niigata-kaigo-stg-app"
```

### 4. SCPの適用

```bash
# SCPポリシーの作成と適用（詳細は scp_policies.json 参照）
aws organizations create-policy \
  --name deny-root-account \
  --type SERVICE_CONTROL_POLICY \
  --content file://scp_policies.json

# 全アカウントに適用
aws organizations attach-policy \
  --policy-id p-xxxx \
  --target-id ou-xxxx
```

---

## コスト管理

### タグ戦略

すべてのリソースに以下のタグを付与：

| タグキー | タグ値例 | 用途 |
|---------|---------|------|
| Project | niigata-kaigo | プロジェクト識別 |
| Environment | production / staging | 環境識別 |
| Owner | team-infra | 管理者識別 |
| CostCenter | fukushi-bu | コストセンター |

### 予算アラート

- 管理アカウントで AWS Budgets を設定
- 月額予算超過時にSNS通知

---

## セキュリティ要件

### MFA必須

- すべてのIAMユーザーでMFA有効化
- SCPで強制

### アクセスキー禁止

- 原則、アクセスキーは発行しない
- IAMロール（AssumeRole）を使用
- デジタル庁承認時のみ例外

### CloudTrail有効化

- 全アカウントでCloudTrail有効化
- ログは本番共通系アカウントのS3バケットに集約

### AWS Config有効化

- 全アカウントでAWS Config有効化
- 構成変更履歴を記録

---

## 次のステップ

- [アカウント構成図を確認](./account_diagram.md)
- [SCPポリシー例を確認](./scp_policies.json)
- [ネットワーク設計を確認](../03_network/)

---

**参照**: GCAS Guidelines - https://guide.gcas.cloud.go.jp/aws/description-of-account-structure
