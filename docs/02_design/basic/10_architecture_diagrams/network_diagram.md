# ネットワーク図

## 目次
1. [全体ネットワーク構成](#全体ネットワーク構成)
2. [本番環境ネットワーク](#本番環境ネットワーク)
3. [ステージング環境ネットワーク](#ステージング環境ネットワーク)
4. [DR環境ネットワーク](#dr環境ネットワーク)

---

## 全体ネットワーク構成

### リージョン間接続

```mermaid
graph TB
    subgraph "us-east-1 (本番環境)"
        VPC1[VPC 10.0.0.0/16]
        subgraph "Public Subnets"
            PUB1A[10.0.0.0/24<br/>us-east-1a]
            PUB1B[10.0.1.0/24<br/>us-east-1b]
        end
        subgraph "Private Subnets"
            PRI1A[10.0.10.0/24<br/>us-east-1a]
            PRI1B[10.0.11.0/24<br/>us-east-1b]
        end
        subgraph "Database Subnets"
            DB1A[10.0.20.0/24<br/>us-east-1a]
            DB1B[10.0.21.0/24<br/>us-east-1b]
        end
    end

    subgraph "us-east-1 (ステージング環境)"
        VPC2[VPC 10.1.0.0/16]
        subgraph "Public Subnets Staging"
            PUB2A[10.1.0.0/24<br/>us-east-1a]
        end
        subgraph "Private Subnets Staging"
            PRI2A[10.1.10.0/24<br/>us-east-1a]
        end
        subgraph "Database Subnets Staging"
            DB2A[10.1.20.0/24<br/>us-east-1a]
        end
    end

    subgraph "us-west-2 (DR環境)"
        VPC3[VPC 10.2.0.0/16]
        subgraph "Public Subnets DR"
            PUB3A[10.2.0.0/24<br/>us-west-2a]
            PUB3B[10.2.1.0/24<br/>us-west-2b]
        end
        subgraph "Private Subnets DR"
            PRI3A[10.2.10.0/24<br/>us-west-2a]
            PRI3B[10.2.11.0/24<br/>us-west-2b]
        end
        subgraph "Database Subnets DR"
            DB3A[10.2.20.0/24<br/>us-west-2a]
            DB3B[10.2.21.0/24<br/>us-west-2b]
        end
    end

    VPC1 -.クロスリージョン<br/>レプリケーション.-> VPC3

    style VPC1 fill:#e1f5ff
    style VPC2 fill:#fff4e1
    style VPC3 fill:#ffe1e1
```

---

## 本番環境ネットワーク

### VPC構成 (us-east-1)

```mermaid
graph TB
    INTERNET[インターネット]
    IGW[Internet Gateway]

    subgraph "VPC 10.0.0.0/16"
        subgraph "Availability Zone A (us-east-1a)"
            subgraph "Public Subnet 10.0.0.0/24"
                ALB_A[ALB]
                NAT_A[NAT Gateway]
            end
            subgraph "Private Subnet 10.0.10.0/24"
                ECS_A[ECS Fargate<br/>Tasks]
                EFS_MT_A[EFS Mount Target]
            end
            subgraph "Database Subnet 10.0.20.0/24"
                RDS_PRIMARY[RDS Primary<br/>db.r6g.large]
                ELASTICACHE_A[ElastiCache<br/>Primary]
            end
        end

        subgraph "Availability Zone B (us-east-1b)"
            subgraph "Public Subnet 10.0.1.0/24"
                ALB_B[ALB]
                NAT_B[NAT Gateway]
            end
            subgraph "Private Subnet 10.0.11.0/24"
                ECS_B[ECS Fargate<br/>Tasks]
                EFS_MT_B[EFS Mount Target]
            end
            subgraph "Database Subnet 10.0.21.0/24"
                RDS_STANDBY[RDS Standby<br/>Multi-AZ]
                ELASTICACHE_B[ElastiCache<br/>Replica]
            end
        end
    end

    INTERNET --> IGW
    IGW --> ALB_A
    IGW --> ALB_B
    ALB_A --> ECS_A
    ALB_B --> ECS_B
    ECS_A --> NAT_A
    ECS_B --> NAT_B
    NAT_A --> IGW
    NAT_B --> IGW

    ECS_A --> RDS_PRIMARY
    ECS_B --> RDS_PRIMARY
    ECS_A --> ELASTICACHE_A
    ECS_B --> ELASTICACHE_B
    ECS_A --> EFS_MT_A
    ECS_B --> EFS_MT_B

    RDS_PRIMARY -.レプリケーション.-> RDS_STANDBY
    ELASTICACHE_A -.レプリケーション.-> ELASTICACHE_B

    style ALB_A fill:#e1f5ff
    style ALB_B fill:#e1f5ff
    style ECS_A fill:#c7f5c7
    style ECS_B fill:#c7f5c7
    style RDS_PRIMARY fill:#ffc7c7
    style RDS_STANDBY fill:#ffc7c7
```

### セキュリティグループ

```mermaid
graph TB
    INTERNET[インターネット<br/>0.0.0.0/0]

    subgraph "Security Groups"
        SG_ALB[ALB SG]
        SG_ECS[ECS SG]
        SG_RDS[RDS SG]
        SG_CACHE[ElastiCache SG]
        SG_EFS[EFS SG]
    end

    INTERNET -->|HTTPS:443<br/>HTTP:80| SG_ALB
    SG_ALB -->|TCP:8080| SG_ECS
    SG_ECS -->|TCP:5432| SG_RDS
    SG_ECS -->|TCP:6379| SG_CACHE
    SG_ECS -->|TCP:2049| SG_EFS

    style SG_ALB fill:#e1f5ff
    style SG_ECS fill:#c7f5c7
    style SG_RDS fill:#ffc7c7
```

### ルートテーブル

#### Public Subnet Route Table

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | igw-xxxxx | インターネット通信 |

#### Private Subnet Route Table (AZ-A)

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | nat-gateway-a | インターネット通信 (NAT Gateway経由) |

#### Private Subnet Route Table (AZ-B)

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | nat-gateway-b | インターネット通信 (NAT Gateway経由) |

#### Database Subnet Route Table

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.0.0.0/16 | local | VPC内通信のみ（インターネットアクセスなし） |

---

## ステージング環境ネットワーク

### VPC構成 (us-east-1)

```mermaid
graph TB
    INTERNET[インターネット]
    IGW[Internet Gateway]

    subgraph "VPC 10.1.0.0/16"
        subgraph "Availability Zone A (us-east-1a)"
            subgraph "Public Subnet 10.1.0.0/24"
                ALB_STG[ALB]
                NAT_STG[NAT Gateway]
            end
            subgraph "Private Subnet 10.1.10.0/24"
                ECS_STG[ECS Fargate<br/>Tasks]
                EFS_MT_STG[EFS Mount Target]
            end
            subgraph "Database Subnet 10.1.20.0/24"
                RDS_STG[RDS Single-AZ<br/>db.t4g.medium]
                ELASTICACHE_STG[ElastiCache<br/>Single Node]
            end
        end
    end

    INTERNET --> IGW
    IGW --> ALB_STG
    ALB_STG --> ECS_STG
    ECS_STG --> NAT_STG
    NAT_STG --> IGW

    ECS_STG --> RDS_STG
    ECS_STG --> ELASTICACHE_STG
    ECS_STG --> EFS_MT_STG

    style ALB_STG fill:#fff4e1
    style ECS_STG fill:#fff4e1
    style RDS_STG fill:#fff4e1
```

**注**: ステージング環境はコスト削減のためシングルAZ構成

---

## DR環境ネットワーク

### VPC構成 (us-west-2)

```mermaid
graph TB
    INTERNET[インターネット]
    IGW[Internet Gateway]

    subgraph "VPC 10.2.0.0/16"
        subgraph "Availability Zone A (us-west-2a)"
            subgraph "Public Subnet 10.2.0.0/24"
                ALB_DR_A[ALB<br/>(DR発動時起動)]
                NAT_DR_A[NAT Gateway]
            end
            subgraph "Private Subnet 10.2.10.0/24"
                ECS_DR_A[ECS Fargate<br/>(DR発動時起動)]
                EFS_MT_DR_A[EFS Mount Target]
            end
            subgraph "Database Subnet 10.2.20.0/24"
                RDS_DR_PRIMARY[RDS<br/>(DR発動時復元)]
                ELASTICACHE_DR_A[ElastiCache<br/>(DR発動時起動)]
            end
        end

        subgraph "Availability Zone B (us-west-2b)"
            subgraph "Public Subnet 10.2.1.0/24"
                ALB_DR_B[ALB<br/>(DR発動時起動)]
                NAT_DR_B[NAT Gateway]
            end
            subgraph "Private Subnet 10.2.11.0/24"
                ECS_DR_B[ECS Fargate<br/>(DR発動時起動)]
                EFS_MT_DR_B[EFS Mount Target]
            end
            subgraph "Database Subnet 10.2.21.0/24"
                RDS_DR_STANDBY[RDS Standby<br/>Multi-AZ]
                ELASTICACHE_DR_B[ElastiCache<br/>Replica]
            end
        end
    end

    INTERNET -.DR発動時.-> IGW
    IGW -.DR発動時.-> ALB_DR_A
    IGW -.DR発動時.-> ALB_DR_B

    style ALB_DR_A fill:#ffe1e1
    style ALB_DR_B fill:#ffe1e1
    style ECS_DR_A fill:#ffe1e1
    style ECS_DR_B fill:#ffe1e1
    style RDS_DR_PRIMARY fill:#ffe1e1
```

**注**: DR環境はVPC、サブネット、セキュリティグループのみ事前構築、リソースはDR発動時に起動

---

## ネットワークACL

### 設計方針

- **NACL**: デフォルトNACL（すべて許可）を使用
- **Security Group**: ステートフルなSecurity Groupで制御

**理由**:
- Security Groupで十分な制御が可能
- NACLはステートレスで管理が複雑
- 将来的に厳格な制御が必要になった場合のみ、カスタムNACLを検討

---

## DNS設計

### Route 53 設定

| レコード名 | タイプ | 値 | TTL | ルーティングポリシー |
|-----------|------|-----|-----|-------------------|
| `api.kaigo-subsys.example.com` | A (ALIAS) | ALB (本番) | 60秒 | Simple |
| `api-stg.kaigo-subsys.example.com` | A (ALIAS) | ALB (ステージング) | 60秒 | Simple |

**DR発動時**:
- `api.kaigo-subsys.example.com` のエイリアスターゲットを DR環境のALBに変更
- TTL 60秒のため、最大1分で切り替わる

---

## VPCエンドポイント

### プライベートサブネットからAWSサービスへのアクセス

| サービス | エンドポイントタイプ | 理由 |
|---------|------------------|------|
| S3 | Gateway型 | コスト削減 |
| ECR | Interface型 | ECSコンテナイメージ取得 |
| CloudWatch Logs | Interface型 | ログ送信 |
| Secrets Manager | Interface型 | 認証情報取得 |

### VPCエンドポイント設定

```mermaid
graph TB
    subgraph "Private Subnet"
        ECS[ECS Fargate]
    end

    subgraph "VPC Endpoints"
        VPCE_S3[S3 Gateway Endpoint]
        VPCE_ECR[ECR Interface Endpoint]
        VPCE_CW[CloudWatch Logs<br/>Interface Endpoint]
        VPCE_SM[Secrets Manager<br/>Interface Endpoint]
    end

    ECS -->|S3アクセス| VPCE_S3
    ECS -->|コンテナイメージ取得| VPCE_ECR
    ECS -->|ログ送信| VPCE_CW
    ECS -->|認証情報取得| VPCE_SM

    VPCE_S3 --> S3[S3 Service]
    VPCE_ECR --> ECR[ECR Service]
    VPCE_CW --> CW[CloudWatch Service]
    VPCE_SM --> SM[Secrets Manager Service]

    style VPCE_S3 fill:#e1f5ff
    style VPCE_ECR fill:#e1f5ff
    style VPCE_CW fill:#e1f5ff
    style VPCE_SM fill:#e1f5ff
```

**メリット**:
- NAT Gateway経由のコストを削減
- AWSサービスへのアクセスがインターネットを経由しない（セキュリティ向上）

---

## 関連ドキュメント

- [ネットワーク設計](../03_network/network_design.md)
- [VPC設計](../03_network/vpc_design.md)
- [セキュリティ設計](../07_security/security_design.md)

---

**作成日**: 2025-11-05
**作成者**: Architect
**バージョン**: 1.0
