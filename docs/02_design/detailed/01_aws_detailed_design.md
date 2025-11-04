# AWS詳細設計書 - 新潟市介護保険事業所システム

## ドキュメント管理情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | AWS詳細設計書 |
| バージョン | 1.0.0 |
| 作成日 | 2025-11-04 |
| 最終更新日 | 2025-11-04 |
| ステータス | Draft |
| 前提ドキュメント | [AWS基本設計書](../basic/01_aws_basic_design.md) |

---

## 目次

1. [ネットワーク詳細設計](#1-ネットワーク詳細設計)
2. [セキュリティ詳細設計](#2-セキュリティ詳細設計)
3. [コンピューティング詳細設計](#3-コンピューティング詳細設計)
4. [データベース詳細設計](#4-データベース詳細設計)
5. [ストレージ詳細設計](#5-ストレージ詳細設計)
6. [CI/CD詳細設計](#6-cicd詳細設計)
7. [監視・運用詳細設計](#7-監視運用詳細設計)
8. [Bedrock運用自動化詳細設計](#8-bedrock運用自動化詳細設計)

---

## 1. ネットワーク詳細設計

### 1.1 VPCルートテーブル設計

#### 1.1.1 prod-app-vpc (本番VPC) ルートテーブル

**Public Subnet Route Table:**

| 宛先CIDR | ターゲット | 説明 | 優先度 |
|---------|-----------|-----|--------|
| 10.1.0.0/16 | local | VPC内通信 | - |
| 0.0.0.0/0 | igw-prod | インターネット向け通信 | - |
| 10.0.0.0/16 | tgw-xxxxxxxxx | 共通VPCへの通信 | - |
| 10.2.0.0/16 | tgw-xxxxxxxxx | ステージングVPCへの通信 (必要時のみ) | - |
| 192.168.0.0/16 | tgw-xxxxxxxxx | オンプレミスへの通信 | - |

**Private App Subnet Route Table:**

| 宛先CIDR | ターゲット | 説明 | 優先度 |
|---------|-----------|-----|--------|
| 10.1.0.0/16 | local | VPC内通信 | - |
| 0.0.0.0/0 | nat-xxxxxxxxx | インターネット向け通信 (NAT経由) | - |
| 10.0.0.0/16 | tgw-xxxxxxxxx | 共通VPCへの通信 | - |
| 192.168.0.0/16 | tgw-xxxxxxxxx | オンプレミスへの通信 | - |

**Private DB Subnet Route Table:**

| 宛先CIDR | ターゲット | 説明 | 優先度 |
|---------|-----------|-----|--------|
| 10.1.0.0/16 | local | VPC内通信 | - |
| 10.0.0.0/16 | tgw-xxxxxxxxx | 共通VPCへの通信 (Route 53 Resolver) | - |
| 192.168.0.0/16 | tgw-xxxxxxxxx | オンプレミスからの管理接続 | - |

**TGW Attachment Subnet Route Table:**

| 宛先CIDR | ターゲット | 説明 | 優先度 |
|---------|-----------|-----|--------|
| 10.1.0.0/16 | local | VPC内通信 | - |
| 0.0.0.0/0 | nat-xxxxxxxxx | Transit Gateway Attachmentからのインターネット通信 | - |

#### 1.1.2 common-vpc (共通VPC) ルートテーブル

**Firewall Subnet Route Table:**

| 宛先CIDR | ターゲット | 説明 | 優先度 |
|---------|-----------|-----|--------|
| 10.0.0.0/16 | local | VPC内通信 | - |
| 10.1.0.0/16 | tgw-xxxxxxxxx | 本番VPCへの通信 (検査後) | - |
| 10.2.0.0/16 | tgw-xxxxxxxxx | ステージングVPCへの通信 (検査後) | - |
| 192.168.0.0/16 | tgw-xxxxxxxxx | オンプレミスへの通信 (検査後) | - |

**TGW Attachment Subnet Route Table:**

| 宛先CIDR | ターゲット | 説明 | 優先度 |
|---------|-----------|-----|--------|
| 10.0.0.0/16 | local | VPC内通信 | - |
| 10.1.0.0/16 | vpce-xxxxxxxxx | Network Firewall Endpointへ | - |
| 10.2.0.0/16 | vpce-xxxxxxxxx | Network Firewall Endpointへ | - |
| 192.168.0.0/16 | vpce-xxxxxxxxx | Network Firewall Endpointへ | - |

### 1.2 Network ACL設計

#### 1.2.1 prod-app-vpc Network ACLs

**Public Subnet NACL:**

| ルール# | タイプ | プロトコル | ポート範囲 | ソース/宛先 | 許可/拒否 | 説明 |
|--------|------|----------|----------|----------|----------|-----|
| **Inbound** |
| 100 | HTTP | TCP | 80 | 0.0.0.0/0 | ALLOW | HTTP (リダイレクト用) |
| 110 | HTTPS | TCP | 443 | 0.0.0.0/0 | ALLOW | HTTPS |
| 120 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | エフェメラルポート (戻り通信) |
| 900 | ALL | ALL | ALL | 0.0.0.0/0 | DENY | デフォルト拒否 |
| **Outbound** |
| 100 | HTTP | TCP | 8080 | 10.1.11.0/24 | ALLOW | ECS Fargateへ |
| 110 | HTTP | TCP | 8080 | 10.1.12.0/24 | ALLOW | ECS Fargateへ |
| 120 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | エフェメラルポート (応答) |
| 900 | ALL | ALL | ALL | 0.0.0.0/0 | DENY | デフォルト拒否 |

**Private App Subnet NACL:**

| ルール# | タイプ | プロトコル | ポート範囲 | ソース/宛先 | 許可/拒否 | 説明 |
|--------|------|----------|----------|----------|----------|-----|
| **Inbound** |
| 100 | HTTP | TCP | 8080 | 10.1.1.0/24 | ALLOW | ALBからの通信 (1a) |
| 110 | HTTP | TCP | 8080 | 10.1.2.0/24 | ALLOW | ALBからの通信 (1c) |
| 120 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | エフェメラルポート |
| 900 | ALL | ALL | ALL | 0.0.0.0/0 | DENY | デフォルト拒否 |
| **Outbound** |
| 100 | PostgreSQL | TCP | 5432 | 10.1.21.0/24 | ALLOW | RDSへの接続 (1a) |
| 110 | PostgreSQL | TCP | 5432 | 10.1.22.0/24 | ALLOW | RDSへの接続 (1c) |
| 120 | Redis | TCP | 6379 | 10.1.31.0/24 | ALLOW | ElastiCacheへの接続 (1a) |
| 130 | Redis | TCP | 6379 | 10.1.32.0/24 | ALLOW | ElastiCacheへの接続 (1c) |
| 140 | HTTPS | TCP | 443 | 0.0.0.0/0 | ALLOW | 外部API呼び出し |
| 150 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | エフェメラルポート |
| 900 | ALL | ALL | ALL | 0.0.0.0/0 | DENY | デフォルト拒否 |

**Private DB Subnet NACL:**

| ルール# | タイプ | プロトコル | ポート範囲 | ソース/宛先 | 許可/拒否 | 説明 |
|--------|------|----------|----------|----------|----------|-----|
| **Inbound** |
| 100 | PostgreSQL | TCP | 5432 | 10.1.11.0/24 | ALLOW | ECS Fargateからの接続 (1a) |
| 110 | PostgreSQL | TCP | 5432 | 10.1.12.0/24 | ALLOW | ECS Fargateからの接続 (1c) |
| 120 | PostgreSQL | TCP | 5432 | 192.168.0.0/16 | ALLOW | オンプレミスからの管理接続 |
| 130 | Custom TCP | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | エフェメラルポート |
| 900 | ALL | ALL | ALL | 0.0.0.0/0 | DENY | デフォルト拒否 |
| **Outbound** |
| 100 | Custom TCP | TCP | 1024-65535 | 10.1.11.0/24 | ALLOW | ECS Fargateへの応答 (1a) |
| 110 | Custom TCP | TCP | 1024-65535 | 10.1.12.0/24 | ALLOW | ECS Fargateへの応答 (1c) |
| 120 | Custom TCP | TCP | 1024-65535 | 192.168.0.0/16 | ALLOW | オンプレミスへの応答 |
| 900 | ALL | ALL | ALL | 0.0.0.0/0 | DENY | デフォルト拒否 |

### 1.3 VPC Endpoint設計

#### 1.3.1 prod-app-vpc VPC Endpoints

| サービス | エンドポイントタイプ | サブネット | セキュリティグループ | 用途 |
|---------|-----------------|----------|-------------------|-----|
| com.amazonaws.ap-northeast-1.s3 | Gateway | - (ルートテーブル) | - | S3へのプライベート接続 |
| com.amazonaws.ap-northeast-1.dynamodb | Gateway | - (ルートテーブル) | - | DynamoDBへのプライベート接続 |
| com.amazonaws.ap-northeast-1.ecr.api | Interface | private-app-subnet-1a, 1c | sg-vpce-ecr | ECRへのプライベート接続 |
| com.amazonaws.ap-northeast-1.ecr.dkr | Interface | private-app-subnet-1a, 1c | sg-vpce-ecr | ECR Dockerへのプライベート接続 |
| com.amazonaws.ap-northeast-1.logs | Interface | private-app-subnet-1a, 1c | sg-vpce-logs | CloudWatch Logsへのプライベート接続 |
| com.amazonaws.ap-northeast-1.monitoring | Interface | private-app-subnet-1a, 1c | sg-vpce-monitoring | CloudWatch Metricsへのプライベート接続 |
| com.amazonaws.ap-northeast-1.secretsmanager | Interface | private-app-subnet-1a, 1c | sg-vpce-secrets | Secrets Managerへのプライベート接続 |
| com.amazonaws.ap-northeast-1.kms | Interface | private-app-subnet-1a, 1c | sg-vpce-kms | KMSへのプライベート接続 |
| com.amazonaws.ap-northeast-1.ssm | Interface | private-app-subnet-1a, 1c | sg-vpce-ssm | Systems Managerへのプライベート接続 |

**VPC Endpoint Security Group (sg-vpce-xxx):**

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|------|----------|----------|-------|-----|
| Inbound | HTTPS | 443 | 10.1.0.0/16 | VPC内からのHTTPS接続 |
| Outbound | ALL | ALL | 0.0.0.0/0 | 全ての送信を許可 |

### 1.4 Direct Connect詳細設計

#### 1.4.1 接続冗長性

```
庁舎 (オンプレミス)
│
├─ CGW-1 (Primary) ────────> Direct Connect Location A (東京)
│                              │
│                              └─> dx-vif-primary (VLAN 100)
│                                   └─> Direct Connect Gateway
│                                        └─> Transit Gateway
│
└─ CGW-2 (Secondary) ──────> Direct Connect Location B (東京)
                               │
                               └─> dx-vif-secondary (VLAN 200)
                                    └─> Direct Connect Gateway
                                         └─> Transit Gateway
```

#### 1.4.2 BGP設定

**Primary VIF (VLAN 100):**

| 項目 | 値 |
|-----|-----|
| VLAN ID | 100 |
| BGP ASN (AWS) | 64512 |
| BGP ASN (Customer) | 65000 |
| BGP Peer IP (AWS) | 169.254.0.1/30 |
| BGP Peer IP (Customer) | 169.254.0.2/30 |
| BGP Authentication | MD5ハッシュ (パスワード: ********) |
| Advertised Prefixes (AWS → Customer) | 10.0.0.0/8 (AWS VPCs) |
| Advertised Prefixes (Customer → AWS) | 192.168.0.0/16 (オンプレミス) |
| BFD (Bidirectional Forwarding Detection) | 有効 (300ms interval, 3 multiplier) |
| Local Preference | 200 (Primary) |

**Secondary VIF (VLAN 200):**

| 項目 | 値 |
|-----|-----|
| VLAN ID | 200 |
| BGP ASN (AWS) | 64512 |
| BGP ASN (Customer) | 65000 |
| BGP Peer IP (AWS) | 169.254.0.5/30 |
| BGP Peer IP (Customer) | 169.254.0.6/30 |
| BGP Authentication | MD5ハッシュ (パスワード: ********) |
| Advertised Prefixes (AWS → Customer) | 10.0.0.0/8 (AWS VPCs) |
| Advertised Prefixes (Customer → AWS) | 192.168.0.0/16 (オンプレミス) |
| BFD | 有効 (300ms interval, 3 multiplier) |
| Local Preference | 100 (Secondary) |

#### 1.4.3 フェイルオーバー設定

**フェイルオーバー条件:**

1. Primary VIFのBGPセッションダウン
2. Primary Direct Connect回線の物理障害
3. BGP Keep-Aliveの3回連続タイムアウト (約900ms)

**フェイルオーバー時間:**

| イベント | 時間 |
|---------|------|
| BFD検出時間 | 300ms × 3 = 900ms |
| BGP Convergence | 約10秒 |
| **合計フェイルオーバー時間** | **約11秒** |

### 1.5 DNS詳細設計

#### 1.5.1 Route 53 レコード設計

**パブリックホストゾーン (kaigo.niigata.jp):**

| レコード名 | タイプ | ルーティングポリシー | 値 | TTL | ヘルスチェック |
|----------|------|------------------|-----|-----|-------------|
| kaigo.niigata.jp | A | Failover (Primary) | CloudFront Distribution (東京) | 60 | 有効 |
| kaigo.niigata.jp | A | Failover (Secondary) | CloudFront Distribution (DR大阪) | 60 | 有効 |
| www.kaigo.niigata.jp | CNAME | Simple | kaigo.niigata.jp | 300 | - |
| api.kaigo.niigata.jp | A | Weighted (100%) | ALB (prod-app-account) | 60 | 有効 |

**プライベートホストゾーン (kaigo.niigata.local):**

| レコード名 | タイプ | 値 | TTL | 関連VPC |
|----------|------|-----|-----|--------|
| db.kaigo.niigata.local | CNAME | kaigo-prod-db.cluster-xxxxx.ap-northeast-1.rds.amazonaws.com | 300 | prod-app-vpc |
| cache.kaigo.niigata.local | CNAME | kaigo-prod-cache.xxxxx.apne1.cache.amazonaws.com | 300 | prod-app-vpc |
| admin-db.kaigo.niigata.local | CNAME | kaigo-prod-db.cluster-ro-xxxxx.ap-northeast-1.rds.amazonaws.com | 300 | prod-app-vpc (Read Replica) |

#### 1.5.2 Route 53 Resolver Rules

**Outbound Endpoint Rules (AWS → オンプレミス):**

| ドメイン名 | ターゲットIP | ポート | 説明 |
|----------|----------|------|-----|
| niigata.local | 192.168.1.53, 192.168.2.53 | 53 | オンプレミスActive Directory DNS |
| city.niigata.jp | 192.168.1.53, 192.168.2.53 | 53 | 庁舎内部ドメイン |

---

## 2. セキュリティ詳細設計

### 2.1 IAMロールとポリシー設計

#### 2.1.1 ECS Task Execution Role (ecsTaskExecutionRole)

**Trust Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Attached Policies:**

1. **AmazonECSTaskExecutionRolePolicy** (AWS Managed)
2. **CustomECRAccessPolicy** (Customer Managed):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRReadAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogsAccess",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:ap-northeast-1:555555555555:log-group:/ecs/kaigo-web-prod:*"
    },
    {
      "Sid": "SecretsManagerAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/db/*",
        "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/app/*"
      ]
    },
    {
      "Sid": "KMSDecryptAccess",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:ap-northeast-1:555555555555:key/*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "secretsmanager.ap-northeast-1.amazonaws.com",
            "logs.ap-northeast-1.amazonaws.com"
          ]
        }
      }
    }
  ]
}
```

#### 2.1.2 ECS Task Role (ecsTaskRole)

**Trust Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Attached Policies:**

**CustomS3AccessPolicy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3DocumentsReadWrite",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::kaigo-prod-documents/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "S3UploadsReadWrite",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::kaigo-prod-uploads/*"
    },
    {
      "Sid": "S3ListBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::kaigo-prod-documents",
        "arn:aws:s3:::kaigo-prod-uploads"
      ]
    }
  ]
}
```

**CustomSNSPublishPolicy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SNSPublish",
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:ap-northeast-1:555555555555:kaigo-notifications"
    }
  ]
}
```

#### 2.1.3 Lambda Execution Role (bedrockIncidentAnalyzerRole)

**Trust Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Attached Policies:**

1. **AWSLambdaVPCAccessExecutionRole** (AWS Managed - VPC内実行の場合)
2. **CustomBedrockAnalysisPolicy**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockInvokeModel",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": "arn:aws:bedrock:ap-northeast-1::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0"
    },
    {
      "Sid": "CloudWatchLogsRead",
      "Effect": "Allow",
      "Action": [
        "logs:FilterLogEvents",
        "logs:GetLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:ap-northeast-1:555555555555:log-group:/ecs/kaigo-web-prod:*",
        "arn:aws:logs:ap-northeast-1:555555555555:log-group:/aws/rds/cluster/kaigo-prod-db:*"
      ]
    },
    {
      "Sid": "CloudWatchMetricsRead",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    },
    {
      "Sid": "RDSPerformanceInsightsRead",
      "Effect": "Allow",
      "Action": [
        "pi:GetResourceMetrics",
        "pi:DescribeDimensionKeys"
      ],
      "Resource": "arn:aws:pi:ap-northeast-1:555555555555:metrics/rds/*"
    },
    {
      "Sid": "SNSPublish",
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:ap-northeast-1:777777777777:incident-notifications"
    }
  ]
}
```

#### 2.1.4 クロスアカウントアクセスロール

**MonitoringRole (prod-app-account → operations-accountからアクセス):**

**Trust Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::777777777777:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "monitoring-external-id-12345"
        }
      }
    }
  ]
}
```

**Attached Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchReadAccess",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DescribeAlarms",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LogsReadAccess",
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:FilterLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2.2 Secrets Manager詳細設計

#### 2.2.1 シークレット構成

| シークレット名 | 説明 | ローテーション | KMSキー | アクセス権限 |
|------------|-----|-----------|--------|----------|
| prod/db/master-password | RDSマスターパスワード | 90日ごと | prod-rds-key | ecsTaskExecutionRole, DBA |
| prod/db/app-password | アプリケーション用DBパスワード | 90日ごと | prod-rds-key | ecsTaskExecutionRole |
| prod/app/jwt-secret | JWT署名用シークレット | 180日ごと | prod-app-key | ecsTaskRole |
| prod/app/api-keys | 外部API連携用キー | 手動 | prod-app-key | ecsTaskRole |
| prod/cache/auth-token | ElastiCache認証トークン | 90日ごと | prod-app-key | ecsTaskExecutionRole |

#### 2.2.2 シークレットローテーション設定

**RDSパスワードローテーション (Lambda):**

```python
# 概要: Lambdaを使用した自動ローテーション
#
# ステップ:
# 1. createSecret: 新しいパスワード生成
# 2. setSecret: RDSに新しいパスワード設定
# 3. testSecret: 新しいパスワードで接続テスト
# 4. finishSecret: ローテーション完了、古いパスワード削除
#
# Lambda関数: RDSPasswordRotationFunction
# トリガー: Secrets Manager (90日ごと)
# IAMロール: rdsPasswordRotationRole
#   - secretsmanager:GetSecretValue, PutSecretValue
#   - rds:ModifyDBInstance
#   - kms:Decrypt, Encrypt
```

### 2.3 AWS WAF詳細ルール設計

#### 2.3.1 カスタムルールグループ: RateLimitRuleGroup

**RateLimitByIP:**

```json
{
  "Name": "RateLimitByIP",
  "Priority": 1,
  "Statement": {
    "RateBasedStatement": {
      "Limit": 2000,
      "AggregateKeyType": "IP",
      "ScopeDownStatement": {
        "NotStatement": {
          "Statement": {
            "IPSetReferenceStatement": {
              "Arn": "arn:aws:wafv2:ap-northeast-1:555555555555:regional/ipset/allowed-ips/xxxxx"
            }
          }
        }
      }
    }
  },
  "Action": {
    "Block": {
      "CustomResponse": {
        "ResponseCode": 429,
        "CustomResponseBodyKey": "rate-limit-exceeded"
      }
    }
  },
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "RateLimitByIP"
  }
}
```

**RateLimitBySession:**

```json
{
  "Name": "RateLimitBySession",
  "Priority": 2,
  "Statement": {
    "RateBasedStatement": {
      "Limit": 500,
      "AggregateKeyType": "CUSTOM_KEYS",
      "CustomKeys": [
        {
          "Cookie": {
            "Name": "session_id",
            "TextTransformations": [
              {
                "Priority": 0,
                "Type": "NONE"
              }
            ]
          }
        }
      ]
    }
  },
  "Action": {
    "Block": {}
  },
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "RateLimitBySession"
  }
}
```

#### 2.3.2 カスタムルールグループ: GeoBlockingRuleGroup

```json
{
  "Name": "GeoBlocking",
  "Priority": 1,
  "Statement": {
    "NotStatement": {
      "Statement": {
        "GeoMatchStatement": {
          "CountryCodes": ["JP"]
        }
      }
    }
  },
  "Action": {
    "Block": {
      "CustomResponse": {
        "ResponseCode": 403,
        "CustomResponseBodyKey": "geo-blocked"
      }
    }
  },
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "GeoBlocking"
  }
}
```

#### 2.3.3 カスタムレスポンスボディ

**rate-limit-exceeded:**

```json
{
  "ContentType": "APPLICATION_JSON",
  "Content": "{\"error\": \"Rate limit exceeded\", \"message\": \"リクエスト数が制限を超えました。しばらくしてから再度お試しください。\", \"retry_after\": 300}"
}
```

**geo-blocked:**

```json
{
  "ContentType": "APPLICATION_JSON",
  "Content": "{\"error\": \"Access denied\", \"message\": \"このサービスは日本国内からのアクセスのみ許可されています。\"}"
}
```

### 2.4 GuardDuty検出設定

#### 2.4.1 検出タイプ別アクション

| 検出タイプ | 重大度 | 自動対応アクション | 通知先 |
|----------|-------|----------------|-------|
| UnauthorizedAccess:EC2/SSHBruteForce | High | Security Group自動更新 (ソースIP遮断) | SNS → Email + Slack |
| Trojan:EC2/DNSDataExfiltration | High | インスタンス隔離 (SG変更) | SNS → Email + Slack + PagerDuty |
| Recon:EC2/PortProbeUnprotectedPort | Medium | CloudWatch Logs記録 | SNS → Email (日次サマリー) |
| UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS | Critical | IAMユーザー無効化 | SNS → Email + Slack + PagerDuty |
| CryptoCurrency:EC2/BitcoinTool.B!DNS | High | インスタンス停止 | SNS → Email + Slack |

#### 2.4.2 GuardDuty自動応答 (EventBridge + Lambda)

**EventBridgeルール:**

```json
{
  "source": ["aws.guardduty"],
  "detail-type": ["GuardDuty Finding"],
  "detail": {
    "severity": [7, 7.0, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 8, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9]
  }
}
```

**Lambda関数 (guardduty-auto-response):**

```python
# 概要: GuardDuty検出時の自動応答
#
# 処理フロー:
# 1. Finding詳細取得
# 2. 検出タイプに応じた対応アクション実行
#    - SSH BruteForce → Security Group更新 (ソースIP遮断)
#    - IAM Credential Exfiltration → IAMユーザー無効化
#    - Malware → インスタンス隔離 (Security Group変更)
# 3. SNS通知 (対応内容含む)
# 4. Systems Manager Incident Manager連携 (Critical時)
#
# IAMロール: guarddutyAutoResponseRole
#   - ec2:AuthorizeSecurityGroupIngress, RevokeSecurityGroupIngress
#   - iam:UpdateAccessKey, DeactivateMFADevice
#   - sns:Publish
```

---

## 3. コンピューティング詳細設計

### 3.1 ECS Fargate詳細設定

#### 3.1.1 タスク定義 (完全版)

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
      "cpu": 1792,
      "memory": 3584,
      "memoryReservation": 3072,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp",
          "appProtocol": "http"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "8080"
        },
        {
          "name": "DB_HOST",
          "value": "db.kaigo.niigata.local"
        },
        {
          "name": "DB_PORT",
          "value": "5432"
        },
        {
          "name": "DB_NAME",
          "value": "kaigo_prod"
        },
        {
          "name": "CACHE_HOST",
          "value": "cache.kaigo.niigata.local"
        },
        {
          "name": "CACHE_PORT",
          "value": "6379"
        },
        {
          "name": "AWS_REGION",
          "value": "ap-northeast-1"
        }
      ],
      "secrets": [
        {
          "name": "DB_USERNAME",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/db/app-password:username::"
        },
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/db/app-password:password::"
        },
        {
          "name": "CACHE_AUTH_TOKEN",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/cache/auth-token:token::"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/app/jwt-secret:secret::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-create-group": "true",
          "awslogs-group": "/ecs/kaigo-web-prod",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs",
          "awslogs-datetime-format": "%Y-%m-%dT%H:%M:%S.%f%z",
          "mode": "non-blocking",
          "max-buffer-size": "25m"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "ulimits": [
        {
          "name": "nofile",
          "softLimit": 65536,
          "hardLimit": 65536
        }
      ],
      "mountPoints": [],
      "volumesFrom": [],
      "readonlyRootFilesystem": false,
      "user": "1000:1000"
    },
    {
      "name": "datadog-agent",
      "image": "public.ecr.aws/datadog/agent:latest",
      "cpu": 256,
      "memory": 512,
      "memoryReservation": 256,
      "essential": false,
      "environment": [
        {
          "name": "DD_SITE",
          "value": "datadoghq.com"
        },
        {
          "name": "DD_ECS_COLLECT_RESOURCE_TAGS_EC2",
          "value": "true"
        },
        {
          "name": "DD_APM_ENABLED",
          "value": "true"
        },
        {
          "name": "DD_APM_NON_LOCAL_TRAFFIC",
          "value": "true"
        }
      ],
      "secrets": [
        {
          "name": "DD_API_KEY",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/datadog/api-key:key::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/datadog-agent",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ],
  "volumes": [],
  "placementConstraints": [],
  "runtimePlatform": {
    "cpuArchitecture": "X86_64",
    "operatingSystemFamily": "LINUX"
  },
  "tags": [
    {
      "key": "Environment",
      "value": "production"
    },
    {
      "key": "Application",
      "value": "kaigo-web"
    }
  ]
}
```

#### 3.1.2 ECSサービス設定 (完全版)

```json
{
  "cluster": "kaigo-prod-cluster",
  "serviceName": "kaigo-web-service",
  "taskDefinition": "kaigo-web-task:1",
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:ap-northeast-1:555555555555:targetgroup/kaigo-web-tg-prod/xxxxx",
      "containerName": "kaigo-web",
      "containerPort": 8080
    }
  ],
  "desiredCount": 2,
  "launchType": "FARGATE",
  "platformVersion": "LATEST",
  "deploymentConfiguration": {
    "deploymentCircuitBreaker": {
      "enable": true,
      "rollback": true
    },
    "maximumPercent": 200,
    "minimumHealthyPercent": 100
  },
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": [
        "subnet-private-app-1a",
        "subnet-private-app-1c"
      ],
      "securityGroups": [
        "sg-ecs-prod"
      ],
      "assignPublicIp": "DISABLED"
    }
  },
  "healthCheckGracePeriodSeconds": 60,
  "schedulingStrategy": "REPLICA",
  "deploymentController": {
    "type": "ECS"
  },
  "placementStrategies": [
    {
      "type": "spread",
      "field": "attribute:ecs.availability-zone"
    }
  ],
  "enableECSManagedTags": true,
  "propagateTags": "SERVICE",
  "enableExecuteCommand": true,
  "tags": [
    {
      "key": "Environment",
      "value": "production"
    }
  ]
}
```

#### 3.1.3 Auto Scaling設定 (完全版)

**Target Tracking Scaling Policy (CPU):**

```json
{
  "ServiceNamespace": "ecs",
  "ResourceId": "service/kaigo-prod-cluster/kaigo-web-service",
  "ScalableDimension": "ecs:service:DesiredCount",
  "PolicyName": "cpu-target-tracking-policy",
  "PolicyType": "TargetTrackingScaling",
  "TargetTrackingScalingPolicyConfiguration": {
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 300
  }
}
```

**Target Tracking Scaling Policy (Memory):**

```json
{
  "ServiceNamespace": "ecs",
  "ResourceId": "service/kaigo-prod-cluster/kaigo-web-service",
  "ScalableDimension": "ecs:service:DesiredCount",
  "PolicyName": "memory-target-tracking-policy",
  "PolicyType": "TargetTrackingScaling",
  "TargetTrackingScalingPolicyConfiguration": {
    "TargetValue": 80.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageMemoryUtilization"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 300
  }
}
```

**Target Tracking Scaling Policy (ALB Request Count):**

```json
{
  "ServiceNamespace": "ecs",
  "ResourceId": "service/kaigo-prod-cluster/kaigo-web-service",
  "ScalableDimension": "ecs:service:DesiredCount",
  "PolicyName": "alb-request-count-policy",
  "PolicyType": "TargetTrackingScaling",
  "TargetTrackingScalingPolicyConfiguration": {
    "TargetValue": 1000.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ALBRequestCountPerTarget",
      "ResourceLabel": "app/kaigo-prod-alb/xxxxx/targetgroup/kaigo-web-tg-prod/yyyyy"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 180
  }
}
```

**Scheduled Scaling (平日朝):**

```json
{
  "ServiceNamespace": "ecs",
  "ResourceId": "service/kaigo-prod-cluster/kaigo-web-service",
  "ScalableDimension": "ecs:service:DesiredCount",
  "ScheduledActionName": "morning-scale-up",
  "Schedule": "cron(0 23 ? * SUN-THU *)",
  "ScalableTargetAction": {
    "MinCapacity": 4,
    "MaxCapacity": 10
  },
  "Timezone": "Asia/Tokyo"
}
```

### 3.2 ALB詳細設定

#### 3.2.1 リスナールール (優先度順)

**HTTPS:443 Listener Rules:**

| 優先度 | 条件 | アクション | 説明 |
|--------|-----|----------|-----|
| 1 | Path = /health | Fixed Response (200 OK) | ヘルスチェックエンドポイント (ALB自身) |
| 2 | Path = /api/v1/* AND Header[X-API-Version] = 1 | Forward to kaigo-api-v1-tg | API v1 トラフィック |
| 3 | Path = /api/v2/* | Forward to kaigo-api-v2-tg | API v2 トラフィック |
| 4 | Host = admin.kaigo.niigata.jp AND Source IP in IPSet | Forward to kaigo-admin-tg | 管理画面 (IP制限) |
| 5 | Path = /static/* | Redirect to CloudFront | 静的コンテンツはCDN経由 |
| Default | - | Forward to kaigo-web-tg-prod | デフォルトルーティング |

**HTTP:80 Listener Rule:**

| 優先度 | 条件 | アクション | 説明 |
|--------|-----|----------|-----|
| Default | - | Redirect to HTTPS (301) | HTTPからHTTPSへリダイレクト |

#### 3.2.2 ALBアクセスログ設定

```json
{
  "LoadBalancerArn": "arn:aws:elasticloadbalancing:ap-northeast-1:555555555555:loadbalancer/app/kaigo-prod-alb/xxxxx",
  "Attributes": [
    {
      "Key": "access_logs.s3.enabled",
      "Value": "true"
    },
    {
      "Key": "access_logs.s3.bucket",
      "Value": "alb-logs-prod"
    },
    {
      "Key": "access_logs.s3.prefix",
      "Value": "kaigo-prod-alb"
    },
    {
      "Key": "idle_timeout.timeout_seconds",
      "Value": "60"
    },
    {
      "Key": "deletion_protection.enabled",
      "Value": "true"
    },
    {
      "Key": "routing.http2.enabled",
      "Value": "true"
    },
    {
      "Key": "routing.http.drop_invalid_header_fields.enabled",
      "Value": "true"
    },
    {
      "Key": "routing.http.desync_mitigation_mode",
      "Value": "defensive"
    },
    {
      "Key": "waf.fail_open.enabled",
      "Value": "false"
    }
  ]
}
```

---

## 4. データベース詳細設計

### 4.1 RDS PostgreSQL詳細設定

#### 4.1.1 DBクラスター設定 (完全版)

```json
{
  "DBClusterIdentifier": "kaigo-prod-db-cluster",
  "Engine": "aurora-postgresql",
  "EngineVersion": "16.1",
  "MasterUsername": "pgadmin",
  "MasterUserPassword": "******* (Secrets Manager経由)",
  "DatabaseName": "kaigo_prod",
  "DBSubnetGroupName": "kaigo-prod-db-subnet-group",
  "VpcSecurityGroupIds": ["sg-rds-prod"],
  "Port": 5432,
  "PreferredBackupWindow": "18:00-19:00",
  "BackupRetentionPeriod": 7,
  "PreferredMaintenanceWindow": "sun:19:00-sun:20:00",
  "EnableCloudwatchLogsExports": ["postgresql"],
  "DeletionProtection": true,
  "StorageEncrypted": true,
  "KmsKeyId": "arn:aws:kms:ap-northeast-1:555555555555:key/prod-rds-key",
  "EnableIAMDatabaseAuthentication": true,
  "DBClusterParameterGroupName": "kaigo-prod-cluster-params",
  "Tags": [
    {
      "Key": "Environment",
      "Value": "production"
    }
  ]
}
```

#### 4.1.2 DBインスタンス設定 (Primary)

```json
{
  "DBInstanceIdentifier": "kaigo-prod-db-instance-1",
  "DBClusterIdentifier": "kaigo-prod-db-cluster",
  "DBInstanceClass": "db.r6g.large",
  "Engine": "aurora-postgresql",
  "PubliclyAccessible": false,
  "AvailabilityZone": "ap-northeast-1a",
  "DBParameterGroupName": "kaigo-prod-instance-params",
  "MonitoringInterval": 60,
  "MonitoringRoleArn": "arn:aws:iam::555555555555:role/rds-monitoring-role",
  "EnablePerformanceInsights": true,
  "PerformanceInsightsRetentionPeriod": 7,
  "PerformanceInsightsKMSKeyId": "arn:aws:kms:ap-northeast-1:555555555555:key/prod-rds-key",
  "PromotionTier": 1,
  "Tags": [
    {
      "Key": "Role",
      "Value": "Primary"
    }
  ]
}
```

#### 4.1.3 カスタムパラメータグループ (クラスターレベル)

```ini
[kaigo-prod-cluster-params]
# 接続設定
max_connections = 500
superuser_reserved_connections = 3

# メモリ設定
shared_buffers = 4GB
effective_cache_size = 12GB
maintenance_work_mem = 512MB
work_mem = 32MB

# WAL設定
wal_buffers = 16MB
max_wal_size = 2GB
min_wal_size = 80MB
checkpoint_completion_target = 0.9

# クエリプランナー設定
random_page_cost = 1.1
effective_io_concurrency = 200
default_statistics_target = 100

# ロギング設定
log_statement = ddl
log_duration = off
log_min_duration_statement = 1000
log_connections = on
log_disconnections = on
log_hostname = off
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# SSL設定
rds.force_ssl = 1
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'

# オートバキューム設定
autovacuum = on
autovacuum_max_workers = 4
autovacuum_naptime = 15s
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05

# 監査設定 (pgaudit)
pgaudit.log = 'ddl, role'
pgaudit.log_catalog = off
pgaudit.log_parameter = on
```

#### 4.1.4 RDSプロキシ設定 (将来対応)

```json
{
  "DBProxyName": "kaigo-prod-rds-proxy",
  "EngineFamily": "POSTGRESQL",
  "Auth": [
    {
      "AuthScheme": "SECRETS",
      "SecretArn": "arn:aws:secretsmanager:ap-northeast-1:555555555555:secret:prod/db/app-password",
      "IAMAuth": "REQUIRED"
    }
  ],
  "RoleArn": "arn:aws:iam::555555555555:role/rds-proxy-role",
  "VpcSubnetIds": [
    "subnet-private-db-1a",
    "subnet-private-db-1c"
  ],
  "VpcSecurityGroupIds": ["sg-rds-proxy"],
  "RequireTLS": true,
  "IdleClientTimeout": 1800,
  "DebugLogging": false,
  "Tags": [
    {
      "Key": "Environment",
      "Value": "production"
    }
  ]
}
```

### 4.2 ElastiCache Redis詳細設定

#### 4.2.1 レプリケーショングループ設定

```json
{
  "ReplicationGroupId": "kaigo-prod-cache",
  "ReplicationGroupDescription": "Production Redis cluster for Kaigo system",
  "Engine": "redis",
  "EngineVersion": "7.0",
  "CacheNodeType": "cache.r6g.large",
  "NumNodeGroups": 2,
  "ReplicasPerNodeGroup": 1,
  "PreferredCacheClusterAZs": [
    "ap-northeast-1a",
    "ap-northeast-1c"
  ],
  "CacheSubnetGroupName": "kaigo-prod-cache-subnet-group",
  "SecurityGroupIds": ["sg-cache-prod"],
  "Port": 6379,
  "PreferredMaintenanceWindow": "sun:19:00-sun:20:00",
  "SnapshotRetentionLimit": 7,
  "SnapshotWindow": "18:00-19:00",
  "TransitEncryptionEnabled": true,
  "AtRestEncryptionEnabled": true,
  "KmsKeyId": "arn:aws:kms:ap-northeast-1:555555555555:key/prod-cache-key",
  "AuthToken": "******* (Secrets Manager経由)",
  "MultiAZEnabled": true,
  "AutomaticFailoverEnabled": true,
  "CacheParameterGroupName": "kaigo-prod-redis-params",
  "NotificationTopicArn": "arn:aws:sns:ap-northeast-1:555555555555:redis-events",
  "LogDeliveryConfigurations": [
    {
      "LogType": "slow-log",
      "DestinationType": "cloudwatch-logs",
      "DestinationDetails": {
        "CloudWatchLogsDetails": {
          "LogGroup": "/aws/elasticache/kaigo-prod-cache/slow-log"
        }
      },
      "LogFormat": "json"
    },
    {
      "LogType": "engine-log",
      "DestinationType": "cloudwatch-logs",
      "DestinationDetails": {
        "CloudWatchLogsDetails": {
          "LogGroup": "/aws/elasticache/kaigo-prod-cache/engine-log"
        }
      },
      "LogFormat": "json"
    }
  ],
  "Tags": [
    {
      "Key": "Environment",
      "Value": "production"
    }
  ]
}
```

#### 4.2.2 カスタムパラメータグループ (Redis)

```ini
[kaigo-prod-redis-params]
# メモリ管理
maxmemory-policy allkeys-lru
maxmemory-samples 5

# タイムアウト設定
timeout 300
tcp-keepalive 300

# パフォーマンス設定
slowlog-log-slower-than 10000
slowlog-max-len 128

# レプリケーション設定
min-replicas-to-write 1
min-replicas-max-lag 10

# クライアント設定
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
```

---

## 5. ストレージ詳細設計

### 5.1 S3バケットポリシー詳細

#### 5.1.1 kaigo-prod-documents バケットポリシー (完全版)

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
    },
    {
      "Sid": "AllowECSTaskAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::555555555555:role/ecsTaskRole"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::kaigo-prod-documents/*"
    },
    {
      "Sid": "AllowCrossAccountBackup",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::777777777777:role/BackupRole"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::kaigo-prod-documents",
        "arn:aws:s3:::kaigo-prod-documents/*"
      ]
    },
    {
      "Sid": "DenyDeleteWithoutMFA",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ],
      "Resource": "arn:aws:s3:::kaigo-prod-documents/*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

### 5.2 S3ライフサイクルポリシー詳細

#### 5.2.1 kaigo-prod-documents ライフサイクルルール

```json
{
  "Rules": [
    {
      "Id": "TransitionToIA",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "Transitions": [
        {
          "Days": 180,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 730,
          "StorageClass": "GLACIER_IR"
        },
        {
          "Days": 2555,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "NoncurrentDays": 90,
          "StorageClass": "GLACIER_IR"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 365
      },
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    }
  ]
}
```

### 5.3 S3レプリケーション詳細

#### 5.3.1 Cross-Region Replication設定

```json
{
  "Role": "arn:aws:iam::555555555555:role/s3-crr-role",
  "Rules": [
    {
      "ID": "ReplicateToOsaka",
      "Status": "Enabled",
      "Priority": 1,
      "Filter": {
        "Prefix": ""
      },
      "Destination": {
        "Bucket": "arn:aws:s3:::kaigo-prod-documents-dr",
        "ReplicationTime": {
          "Status": "Enabled",
          "Time": {
            "Minutes": 15
          }
        },
        "Metrics": {
          "Status": "Enabled",
          "EventThreshold": {
            "Minutes": 15
          }
        },
        "StorageClass": "STANDARD_IA",
        "EncryptionConfiguration": {
          "ReplicaKmsKeyID": "arn:aws:kms:ap-northeast-3:555555555555:key/dr-s3-key"
        }
      },
      "DeleteMarkerReplication": {
        "Status": "Enabled"
      },
      "SourceSelectionCriteria": {
        "SseKmsEncryptedObjects": {
          "Status": "Enabled"
        },
        "ReplicaModifications": {
          "Status": "Enabled"
        }
      },
      "ExistingObjectReplication": {
        "Status": "Enabled"
      }
    }
  ]
}
```

---

## 6. CI/CD詳細設計

### 6.1 ECRリポジトリ設定

#### 6.1.1 リポジトリポリシー

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPushPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::555555555555:role/GitHubActionsRole",
          "arn:aws:iam::555555555555:role/ecsTaskExecutionRole"
        ]
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
    },
    {
      "Sid": "AllowCrossAccountPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::666666666666:role/ecsTaskExecutionRole"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }
  ]
}
```

#### 6.1.2 イメージスキャン設定

```json
{
  "RepositoryName": "kaigo-web",
  "ImageScanningConfiguration": {
    "ScanOnPush": true
  },
  "ImageTagMutability": "IMMUTABLE",
  "EncryptionConfiguration": {
    "EncryptionType": "KMS",
    "KmsKey": "arn:aws:kms:ap-northeast-1:555555555555:key/prod-ecr-key"
  }
}
```

#### 6.1.3 ライフサイクルポリシー

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 production images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["prod-"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Keep last 3 staging images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["staging-"],
        "countType": "imageCountMoreThan",
        "countNumber": 3
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "Remove untagged images older than 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

### 6.2 GitHub Actions詳細設計

#### 6.2.1 IAMロール (OIDC認証)

**Trust Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::555555555555:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:k-tanaka-522/niigatacity-kaigo-subsystem:*"
        }
      }
    }
  ]
}
```

**Permissions Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSDeployAccess",
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:RegisterTaskDefinition",
        "ecs:DescribeTaskDefinition"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::555555555555:role/ecsTaskExecutionRole",
        "arn:aws:iam::555555555555:role/ecsTaskRole"
      ]
    }
  ]
}
```

#### 6.2.2 GitHub Actions Workflow (本番デプロイ)

```.github/workflows/deploy-production.yml``` は後述のCI/CD設計ドキュメントで詳述します。

---

## 7. 監視・運用詳細設計

### 7.1 CloudWatch Alarms詳細設定

#### 7.1.1 ECS Fargate Alarms

**CPU使用率 (Warning):**

```json
{
  "AlarmName": "ECS-CPU-Warning-Prod",
  "AlarmDescription": "ECS CPU使用率が70%を超えた場合",
  "ActionsEnabled": true,
  "AlarmActions": [
    "arn:aws:sns:ap-northeast-1:777777777777:ops-notifications"
  ],
  "MetricName": "CPUUtilization",
  "Namespace": "AWS/ECS",
  "Statistic": "Average",
  "Dimensions": [
    {
      "Name": "ServiceName",
      "Value": "kaigo-web-service"
    },
    {
      "Name": "ClusterName",
      "Value": "kaigo-prod-cluster"
    }
  ],
  "Period": 300,
  "EvaluationPeriods": 2,
  "Threshold": 70.0,
  "ComparisonOperator": "GreaterThanThreshold",
  "TreatMissingData": "notBreaching"
}
```

**Task Count (Critical):**

```json
{
  "AlarmName": "ECS-TaskCount-Critical-Prod",
  "AlarmDescription": "実行中タスク数が最小値(2)を下回った場合",
  "ActionsEnabled": true,
  "AlarmActions": [
    "arn:aws:sns:ap-northeast-1:777777777777:critical-alerts",
    "arn:aws:lambda:ap-northeast-1:777777777777:function:ecs-task-restarter"
  ],
  "MetricName": "RunningTaskCount",
  "Namespace": "ECS/ContainerInsights",
  "Statistic": "Average",
  "Dimensions": [
    {
      "Name": "ServiceName",
      "Value": "kaigo-web-service"
    },
    {
      "Name": "ClusterName",
      "Value": "kaigo-prod-cluster"
    }
  ],
  "Period": 60,
  "EvaluationPeriods": 1,
  "Threshold": 2.0,
  "ComparisonOperator": "LessThanThreshold",
  "TreatMissingData": "breaching"
}
```

#### 7.1.2 RDS Alarms

**Connection Count:**

```json
{
  "AlarmName": "RDS-ConnectionCount-Warning-Prod",
  "AlarmDescription": "RDS接続数が400を超えた場合",
  "ActionsEnabled": true,
  "AlarmActions": [
    "arn:aws:sns:ap-northeast-1:777777777777:ops-notifications",
    "arn:aws:lambda:ap-northeast-1:777777777777:function:bedrock-incident-analyzer"
  ],
  "MetricName": "DatabaseConnections",
  "Namespace": "AWS/RDS",
  "Statistic": "Average",
  "Dimensions": [
    {
      "Name": "DBClusterIdentifier",
      "Value": "kaigo-prod-db-cluster"
    }
  ],
  "Period": 300,
  "EvaluationPeriods": 2,
  "Threshold": 400.0,
  "ComparisonOperator": "GreaterThanThreshold",
  "TreatMissingData": "notBreaching"
}
```

### 7.2 CloudWatch Logs Insights定期クエリ

#### 7.2.1 定期実行クエリ (EventBridge Schedule)

**日次エラーサマリー (毎朝9時実行):**

```cloudwatch
fields @timestamp, level, message, request_id
| filter level = "ERROR"
| stats count() as error_count by bin(24h) as day, message
| sort error_count desc
| limit 20
```

**週次パフォーマンスレポート (毎週月曜9時実行):**

```cloudwatch
fields @timestamp, endpoint, response_time
| filter response_time > 1000
| stats avg(response_time) as avg_ms, max(response_time) as max_ms, count() as slow_count by endpoint
| sort avg_ms desc
| limit 50
```

---

## 8. Bedrock運用自動化詳細設計

### 8.1 Lambda関数 (bedrock-incident-analyzer) 実装詳細

#### 8.1.1 関数構成

| 項目 | 値 |
|-----|-----|
| 関数名 | bedrock-incident-analyzer |
| ランタイム | Python 3.12 |
| アーキテクチャ | arm64 (Graviton2) |
| メモリ | 512 MB |
| タイムアウト | 300秒 (5分) |
| 環境変数 | BEDROCK_MODEL_ID, SNS_TOPIC_ARN, LOG_LEVEL |
| VPC | prod-app-vpc (VPC Endpoint経由でBedrock接続) |
| 予約済み同時実行数 | 10 |
| レイヤー | boto3-layer (最新Boto3), requests-layer |

#### 8.1.2 処理フロー図

```
EventBridge (CloudWatch Alarm)
    │
    └──> Lambda (bedrock-incident-analyzer)
           │
           ├─ 1. イベント解析 (Alarm情報抽出)
           │
           ├─ 2. 関連データ収集
           │    ├─ CloudWatch Logs Insights (エラーログ)
           │    ├─ CloudWatch Metrics (CPU, Memory等)
           │    └─ RDS Performance Insights (遅いクエリ)
           │
           ├─ 3. Bedrock呼び出し
           │    ├─ プロンプト生成 (テンプレート使用)
           │    ├─ Claude 3.5 Sonnet v2呼び出し
           │    └─ レスポンス解析
           │
           ├─ 4. 分析結果整形
           │    ├─ Markdown形式
           │    └─ Slack Block Kit形式
           │
           └─ 5. 通知送信
                ├─ SNS (Email)
                └─ Slack Webhook (オプション)
```

#### 8.1.3 コスト分析

| 項目 | 月間想定 | 単価 | 月額コスト |
|-----|---------|------|-----------|
| Lambda実行時間 | 50回 × 30秒 = 1,500秒 | $0.0000133334/GB-秒 | $0.01 |
| Lambda実行回数 | 50回 | $0.20/100万リクエスト | $0.00 |
| Bedrock入力トークン | 50回 × 8,000トークン | $3.00/MTok | $1.20 |
| Bedrock出力トークン | 50回 × 1,500トークン | $15.00/MTok | $1.13 |
| CloudWatch Logs Insights | 50クエリ × 1 GB | $0.005/GB | $0.25 |
| **合計** | | | **$2.59/月** |

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
| 開発リーダー | | | |

---

**次のドキュメント:** [IaC設計書](02_terraform_design.md)
