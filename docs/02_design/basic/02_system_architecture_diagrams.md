# システム構成図

## 目次

1. [マルチアカウント構成図](#1-マルチアカウント構成図)
2. [全体システム構成図](#2-全体システム構成図)
3. [ネットワーク構成図](#3-ネットワーク構成図)
4. [本番環境詳細構成図](#4-本番環境詳細構成図)
5. [セキュリティ構成図](#5-セキュリティ構成図)
6. [データフロー図](#6-データフロー図)
7. [DR構成図](#7-dr構成図)

---

## 1. マルチアカウント構成図

```mermaid
graph TB
    subgraph "AWS Organizations"
        ROOT[Management Account<br/>新潟市AWS組織管理]

        subgraph "Security OU"
            AUDIT[Audit Account<br/>監査ログ・証跡管理]
            SECURITY[Security Account<br/>セキュリティサービス統合]
        end

        subgraph "Infrastructure OU"
            COMMON[Common Account<br/>共通系インフラ<br/>Direct Connect, Transit GW]
        end

        subgraph "Workloads OU"
            PROD[Production Account<br/>本番アプリケーション<br/>ECS, RDS, ElastiCache]
            STAGING[Staging Account<br/>ステージング環境<br/>T系インスタンス]
        end

        subgraph "Operations OU"
            OPS[Operations Account<br/>運用系<br/>監視, ログ集約, Bedrock]
        end
    end

    ROOT -->|SCPs適用| AUDIT
    ROOT -->|SCPs適用| SECURITY
    ROOT -->|SCPs適用| COMMON
    ROOT -->|SCPs適用| PROD
    ROOT -->|SCPs適用| STAGING
    ROOT -->|SCPs適用| OPS

    SECURITY -->|GuardDuty<br/>Security Hub| PROD
    SECURITY -->|GuardDuty<br/>Security Hub| STAGING
    SECURITY -->|GuardDuty<br/>Security Hub| COMMON

    AUDIT -->|CloudTrail<br/>Config| PROD
    AUDIT -->|CloudTrail<br/>Config| STAGING
    AUDIT -->|CloudTrail<br/>Config| COMMON

    OPS -->|CloudWatch Logs<br/>集約| PROD
    OPS -->|CloudWatch Logs<br/>集約| STAGING

    COMMON -->|Transit Gateway<br/>Direct Connect| PROD
    COMMON -->|Transit Gateway<br/>Direct Connect| STAGING

    style ROOT fill:#ff9999
    style SECURITY fill:#ffcc99
    style AUDIT fill:#ffcc99
    style COMMON fill:#99ccff
    style PROD fill:#99ff99
    style STAGING fill:#ccffcc
    style OPS fill:#cc99ff
```

---

## 2. 全体システム構成図

```mermaid
graph TB
    subgraph "庁舎内ネットワーク"
        USER[職員端末<br/>1,300+ ユーザー<br/>430+ 事業所]
        ONPREM[オンプレミスシステム<br/>既存基幹システム]
    end

    subgraph "AWS Direct Connect"
        DX1[Direct Connect<br/>1Gbps - Primary]
        DX2[Direct Connect<br/>1Gbps - Secondary]
        DXGW[Direct Connect Gateway]
    end

    subgraph "Common Account - ap-northeast-1"
        TGW[Transit Gateway]
        NFW[Network Firewall]

        subgraph "共通サービス"
            DNS[Route 53<br/>Private Hosted Zone]
            ENDPOINT[VPC Endpoints<br/>PrivateLink]
        end
    end

    subgraph "Production Account - ap-northeast-1"
        subgraph "VPC 10.1.0.0/16"
            CF[CloudFront<br/>CDN]
            WAF[AWS WAF]

            subgraph "Public Subnet"
                ALB[Application Load Balancer<br/>Multi-AZ]
                NAT1[NAT Gateway - AZ1]
                NAT2[NAT Gateway - AZ2]
            end

            subgraph "Private App Subnet"
                ECS1[ECS Fargate<br/>Web/API - AZ1<br/>2 vCPU / 4GB RAM]
                ECS2[ECS Fargate<br/>Web/API - AZ2<br/>2 vCPU / 4GB RAM]
            end

            subgraph "Private DB Subnet"
                RDS_PRIMARY[RDS Aurora PostgreSQL<br/>Primary - AZ1<br/>db.r6g.large]
                RDS_REPLICA[RDS Aurora PostgreSQL<br/>Replica - AZ2<br/>db.r6g.large]
            end

            subgraph "Private Cache Subnet"
                REDIS1[ElastiCache Redis<br/>cache.r6g.large - AZ1]
                REDIS2[ElastiCache Redis<br/>cache.r6g.large - AZ2]
            end
        end
    end

    subgraph "Operations Account"
        CW[CloudWatch Logs<br/>ログ集約]
        BEDROCK[Amazon Bedrock<br/>Claude 3.5 Sonnet v2<br/>障害一次調査自動化]
        BACKUP[AWS Backup<br/>バックアップ管理]
    end

    subgraph "Security Account"
        GUARD[GuardDuty<br/>脅威検知]
        SECHUB[Security Hub<br/>セキュリティ統合]
        INSPECTOR[Inspector<br/>脆弱性スキャン]
    end

    subgraph "Audit Account"
        TRAIL[CloudTrail<br/>監査証跡]
        CONFIG[AWS Config<br/>構成管理]
        S3_AUDIT[S3 Bucket<br/>監査ログ保管]
    end

    subgraph "Disaster Recovery - ap-northeast-3 (Osaka)"
        DR_RDS[RDS Aurora<br/>Read Replica<br/>Cross-Region]
        DR_S3[S3 Bucket<br/>Cross-Region<br/>Replication]
    end

    USER -->|HTTPS| DX1
    USER -->|HTTPS| DX2
    ONPREM -->|API連携| DX1

    DX1 --> DXGW
    DX2 --> DXGW
    DXGW --> TGW

    TGW --> NFW
    NFW --> CF

    CF -->|HTTPS| WAF
    WAF --> ALB

    ALB --> ECS1
    ALB --> ECS2

    ECS1 --> REDIS1
    ECS2 --> REDIS2

    ECS1 --> RDS_PRIMARY
    ECS2 --> RDS_PRIMARY

    RDS_PRIMARY -.->|レプリケーション| RDS_REPLICA
    RDS_PRIMARY -.->|Cross-Region<br/>レプリケーション| DR_RDS

    ECS1 -->|ログ出力| CW
    ECS2 -->|ログ出力| CW

    CW -->|異常検知| BEDROCK

    RDS_PRIMARY -->|バックアップ| BACKUP
    BACKUP -.->|Cross-Region<br/>バックアップ| DR_S3

    GUARD -->|脅威通知| SECHUB
    INSPECTOR -->|脆弱性通知| SECHUB

    style USER fill:#e1f5ff
    style CF fill:#ff9999
    style WAF fill:#ffcc99
    style ALB fill:#99ccff
    style ECS1 fill:#99ff99
    style ECS2 fill:#99ff99
    style RDS_PRIMARY fill:#ffcc99
    style RDS_REPLICA fill:#ffe6cc
    style REDIS1 fill:#cc99ff
    style REDIS2 fill:#cc99ff
    style BEDROCK fill:#ff99cc
    style DR_RDS fill:#ffcccc
    style DR_S3 fill:#ffcccc
```

---

## 3. ネットワーク構成図

```mermaid
graph TB
    subgraph "庁舎内 - 10.0.0.0/8"
        OFFICE[新潟市庁舎<br/>職員端末ネットワーク]
    end

    subgraph "Direct Connect 1Gbps × 2"
        DX1[Direct Connect 1<br/>Primary - Tokyo]
        DX2[Direct Connect 2<br/>Secondary - Tokyo]
    end

    subgraph "Common Account - Transit Gateway"
        TGW[Transit Gateway<br/>ap-northeast-1]
        TGW_RT[TGW Route Table<br/>ルーティング制御]

        subgraph "Common VPC - 10.0.0.0/16"
            NFW_SUBNET1[Network Firewall<br/>Subnet - AZ1<br/>10.0.1.0/24]
            NFW_SUBNET2[Network Firewall<br/>Subnet - AZ2<br/>10.0.2.0/24]

            NFW_EP1[Network Firewall<br/>Endpoint - AZ1]
            NFW_EP2[Network Firewall<br/>Endpoint - AZ2]
        end
    end

    subgraph "Production Account"
        subgraph "Prod VPC - 10.1.0.0/16"
            subgraph "Public Subnets"
                PUB1[Public Subnet - AZ1<br/>10.1.1.0/24<br/>NAT Gateway, ALB]
                PUB2[Public Subnet - AZ2<br/>10.1.2.0/24<br/>NAT Gateway, ALB]
            end

            subgraph "Private App Subnets"
                APP1[Private App - AZ1<br/>10.1.11.0/24<br/>ECS Fargate]
                APP2[Private App - AZ2<br/>10.1.12.0/24<br/>ECS Fargate]
            end

            subgraph "Private DB Subnets"
                DB1[Private DB - AZ1<br/>10.1.21.0/24<br/>RDS Primary]
                DB2[Private DB - AZ2<br/>10.1.22.0/24<br/>RDS Replica]
            end

            subgraph "Private Cache Subnets"
                CACHE1[Private Cache - AZ1<br/>10.1.31.0/24<br/>ElastiCache]
                CACHE2[Private Cache - AZ2<br/>10.1.32.0/24<br/>ElastiCache]
            end

            IGW_PROD[Internet Gateway]
        end
    end

    subgraph "Staging Account"
        subgraph "Staging VPC - 10.2.0.0/16"
            subgraph "Public Subnets"
                STG_PUB1[Public Subnet - AZ1<br/>10.2.1.0/24]
                STG_PUB2[Public Subnet - AZ2<br/>10.2.2.0/24]
            end

            subgraph "Private App Subnets"
                STG_APP1[Private App - AZ1<br/>10.2.11.0/24<br/>ECS Fargate T系]
                STG_APP2[Private App - AZ2<br/>10.2.12.0/24<br/>ECS Fargate T系]
            end

            subgraph "Private DB Subnets"
                STG_DB1[Private DB - AZ1<br/>10.2.21.0/24<br/>RDS db.t4g.medium]
            end

            IGW_STG[Internet Gateway]
        end
    end

    OFFICE -->|BGP<br/>AS 65000| DX1
    OFFICE -->|BGP<br/>AS 65000| DX2

    DX1 --> TGW
    DX2 --> TGW

    TGW --> TGW_RT

    TGW_RT -->|検査トラフィック| NFW_EP1
    TGW_RT -->|検査トラフィック| NFW_EP2

    NFW_EP1 --> PUB1
    NFW_EP1 --> PUB2
    NFW_EP2 --> STG_PUB1
    NFW_EP2 --> STG_PUB2

    PUB1 -.->|NAT| APP1
    PUB2 -.->|NAT| APP2

    APP1 --> DB1
    APP1 --> CACHE1
    APP2 --> DB2
    APP2 --> CACHE2

    STG_PUB1 -.->|NAT| STG_APP1
    STG_PUB2 -.->|NAT| STG_APP2
    STG_APP1 --> STG_DB1

    PUB1 --> IGW_PROD
    PUB2 --> IGW_PROD
    STG_PUB1 --> IGW_STG
    STG_PUB2 --> IGW_STG

    style OFFICE fill:#e1f5ff
    style TGW fill:#ffcc99
    style NFW_EP1 fill:#ff9999
    style NFW_EP2 fill:#ff9999
    style PUB1 fill:#99ccff
    style PUB2 fill:#99ccff
    style APP1 fill:#99ff99
    style APP2 fill:#99ff99
    style DB1 fill:#ffcc99
    style DB2 fill:#ffcc99
    style CACHE1 fill:#cc99ff
    style CACHE2 fill:#cc99ff
```

---

## 4. 本番環境詳細構成図

```mermaid
graph TB
    subgraph "Internet"
        INTERNET[インターネット]
    end

    subgraph "CloudFront Distribution"
        CF[CloudFront<br/>グローバルエッジロケーション<br/>TLS 1.3]
    end

    subgraph "Production VPC - 10.1.0.0/16 - ap-northeast-1"
        subgraph "AWS WAF"
            WAF[WAF WebACL<br/>OWASP Top 10対策<br/>Rate Limiting]
        end

        subgraph "Public Subnet - AZ1 (10.1.1.0/24)"
            ALB1[Application Load Balancer<br/>Target Group: ECS<br/>Health Check: /health]
            NAT1[NAT Gateway<br/>固定EIP]
        end

        subgraph "Public Subnet - AZ2 (10.1.2.0/24)"
            NAT2[NAT Gateway<br/>固定EIP]
        end

        subgraph "Private App Subnet - AZ1 (10.1.11.0/24)"
            ECS_TASK1_1[ECS Task 1<br/>Web/API Container<br/>2 vCPU / 4GB]
            ECS_TASK1_2[ECS Task 2<br/>Web/API Container<br/>2 vCPU / 4GB]

            subgraph "Container"
                APP1[Application<br/>Node.js / Python]
                XRAY1[X-Ray Daemon<br/>分散トレーシング]
            end
        end

        subgraph "Private App Subnet - AZ2 (10.1.12.0/24)"
            ECS_TASK2_1[ECS Task 3<br/>Web/API Container<br/>2 vCPU / 4GB]
            ECS_TASK2_2[ECS Task 4<br/>Web/API Container<br/>2 vCPU / 4GB]
        end

        subgraph "Private DB Subnet - AZ1 (10.1.21.0/24)"
            RDS_W[Aurora PostgreSQL<br/>Writer Instance<br/>db.r6g.large<br/>2 vCPU / 16GB RAM]
        end

        subgraph "Private DB Subnet - AZ2 (10.1.22.0/24)"
            RDS_R[Aurora PostgreSQL<br/>Reader Instance<br/>db.r6g.large<br/>2 vCPU / 16GB RAM]
        end

        subgraph "Private Cache Subnet - AZ1 (10.1.31.0/24)"
            REDIS_M[ElastiCache Redis<br/>Primary Node<br/>cache.r6g.large<br/>13.07GB RAM]
            REDIS_R1[ElastiCache Redis<br/>Replica Node 1]
        end

        subgraph "Private Cache Subnet - AZ2 (10.1.32.0/24)"
            REDIS_R2[ElastiCache Redis<br/>Replica Node 2]
            REDIS_R3[ElastiCache Redis<br/>Replica Node 3]
        end

        subgraph "VPC Endpoints"
            EP_S3[S3 Gateway Endpoint]
            EP_ECR_API[ECR API Endpoint<br/>PrivateLink]
            EP_ECR_DKR[ECR DKR Endpoint<br/>PrivateLink]
            EP_LOGS[CloudWatch Logs<br/>Endpoint]
            EP_SECRETS[Secrets Manager<br/>Endpoint]
        end

        subgraph "Security Groups"
            SG_ALB[SG: ALB<br/>Ingress: 443<br/>Egress: ECS]
            SG_ECS[SG: ECS<br/>Ingress: ALB only<br/>Egress: DB, Cache]
            SG_RDS[SG: RDS<br/>Ingress: ECS only 5432<br/>Egress: None]
            SG_REDIS[SG: Redis<br/>Ingress: ECS only 6379<br/>Egress: None]
        end
    end

    subgraph "AWS Managed Services"
        ECR[ECR<br/>Container Registry<br/>イメージスキャン有効]
        SECRETS[Secrets Manager<br/>DB認証情報<br/>自動ローテーション]
        KMS[KMS<br/>暗号化キー管理<br/>CMK]
        S3[S3 Bucket<br/>静的コンテンツ<br/>アプリケーションログ]
        CW[CloudWatch Logs<br/>アプリケーションログ<br/>保持期間: 90日]
        XRAY_SVC[AWS X-Ray<br/>トレース分析]
    end

    INTERNET -->|HTTPS| CF
    CF -->|HTTPS| WAF
    WAF -->|HTTPS| ALB1

    ALB1 -->|HTTP 8080| ECS_TASK1_1
    ALB1 -->|HTTP 8080| ECS_TASK1_2
    ALB1 -->|HTTP 8080| ECS_TASK2_1
    ALB1 -->|HTTP 8080| ECS_TASK2_2

    ECS_TASK1_1 -->|PostgreSQL 5432| RDS_W
    ECS_TASK1_2 -->|PostgreSQL 5432| RDS_W
    ECS_TASK2_1 -->|PostgreSQL 5432| RDS_W
    ECS_TASK2_2 -->|PostgreSQL 5432| RDS_W

    ECS_TASK1_1 -->|Read Query| RDS_R
    ECS_TASK2_1 -->|Read Query| RDS_R

    RDS_W -.->|同期レプリケーション| RDS_R

    ECS_TASK1_1 -->|Redis 6379| REDIS_M
    ECS_TASK1_2 -->|Redis 6379| REDIS_M
    ECS_TASK2_1 -->|Redis 6379| REDIS_M
    ECS_TASK2_2 -->|Redis 6379| REDIS_M

    REDIS_M -.->|非同期レプリケーション| REDIS_R1
    REDIS_M -.->|非同期レプリケーション| REDIS_R2
    REDIS_M -.->|非同期レプリケーション| REDIS_R3

    ECS_TASK1_1 -->|コンテナイメージ取得| EP_ECR_API
    ECS_TASK1_1 -->|コンテナイメージ取得| EP_ECR_DKR

    EP_ECR_API --> ECR
    EP_ECR_DKR --> ECR

    ECS_TASK1_1 -->|DB認証情報取得| EP_SECRETS
    EP_SECRETS --> SECRETS

    ECS_TASK1_1 -->|ログ出力| EP_LOGS
    EP_LOGS --> CW

    APP1 -->|トレース送信| XRAY1
    XRAY1 --> XRAY_SVC

    ECS_TASK1_1 -->|静的コンテンツ| EP_S3
    EP_S3 --> S3

    RDS_W -->|暗号化| KMS
    SECRETS -->|暗号化| KMS
    S3 -->|暗号化| KMS

    style CF fill:#ff9999
    style WAF fill:#ffcc99
    style ALB1 fill:#99ccff
    style ECS_TASK1_1 fill:#99ff99
    style ECS_TASK1_2 fill:#99ff99
    style ECS_TASK2_1 fill:#99ff99
    style ECS_TASK2_2 fill:#99ff99
    style RDS_W fill:#ffcc99
    style RDS_R fill:#ffe6cc
    style REDIS_M fill:#cc99ff
    style REDIS_R1 fill:#e6ccff
    style REDIS_R2 fill:#e6ccff
    style REDIS_R3 fill:#e6ccff
```

---

## 5. セキュリティ構成図

```mermaid
graph TB
    subgraph "Security Account - セキュリティ統合"
        SECHUB[Security Hub<br/>セキュリティ統合ダッシュボード<br/>CIS Benchmark]
        GUARD[GuardDuty<br/>脅威検知<br/>機械学習ベース]
        INSPECTOR[Inspector<br/>脆弱性スキャン<br/>CVE検出]
        MACIE[Macie<br/>機密データ検出<br/>S3スキャン]
    end

    subgraph "Audit Account - 監査・証跡"
        TRAIL[CloudTrail<br/>API操作ログ<br/>全アカウント統合]
        CONFIG[AWS Config<br/>構成変更履歴<br/>コンプライアンス]
        S3_AUDIT[S3 Bucket<br/>監査ログ保管<br/>暗号化 + MFA削除]
    end

    subgraph "Production Account - 本番環境"
        subgraph "境界防御"
            WAF_PROD[AWS WAF<br/>WebACL<br/>- SQLi防御<br/>- XSS防御<br/>- Rate Limiting]
            NFW_PROD[Network Firewall<br/>- IDS/IPS<br/>- ドメインフィルタリング]
            SHIELD[AWS Shield Standard<br/>DDoS防御]
        end

        subgraph "アクセス制御"
            IAM_PROD[IAM Roles<br/>- ECS Task Role<br/>- Lambda Execution Role<br/>最小権限の原則]
            COGNITO[Amazon Cognito<br/>ユーザー認証<br/>MFA必須]
        end

        subgraph "暗号化"
            KMS_PROD[KMS CMK<br/>- RDS暗号化<br/>- S3暗号化<br/>- Secrets Manager]
            ACM[AWS Certificate Manager<br/>TLS証明書管理<br/>自動更新]
        end

        subgraph "ネットワーク分離"
            SG_PROD[Security Groups<br/>ステートフルファイアウォール<br/>最小権限ルール]
            NACL[Network ACLs<br/>ステートレスファイアウォール<br/>サブネット境界防御]
            PRIVLINK[VPC PrivateLink<br/>AWS Endpoints<br/>インターネット経由なし]
        end

        subgraph "データ保護"
            RDS_ENC[RDS暗号化<br/>保管時: KMS<br/>転送時: TLS]
            S3_ENC[S3暗号化<br/>SSE-KMS<br/>バージョニング有効]
            BACKUP_ENC[AWS Backup<br/>暗号化バックアップ<br/>Cross-Region]
        end

        subgraph "ログ・監視"
            FLOWLOG[VPC Flow Logs<br/>全ネットワークトラフィック<br/>CloudWatch Logs]
            CLOUDWATCH[CloudWatch Alarms<br/>異常検知<br/>自動通知]
            XRAY[AWS X-Ray<br/>分散トレーシング<br/>セキュリティ異常検出]
        end
    end

    subgraph "Operations Account - 運用監視"
        BEDROCK_SEC[Bedrock<br/>セキュリティインシデント<br/>一次調査自動化]
        SNS[SNS Topics<br/>セキュリティアラート通知<br/>エスカレーション]
        EVENTBRIDGE[EventBridge<br/>セキュリティイベント<br/>自動対応]
    end

    subgraph "外部連携"
        DIRECTCONNECT[Direct Connect<br/>専用線接続<br/>MACsec暗号化]
        VPN_BACKUP[Site-to-Site VPN<br/>バックアップ接続<br/>IPsec]
    end

    GUARD -->|脅威検知結果| SECHUB
    INSPECTOR -->|脆弱性レポート| SECHUB
    MACIE -->|機密データ検出| SECHUB
    CONFIG -->|コンプライアンス評価| SECHUB

    TRAIL -->|全API操作| S3_AUDIT
    CONFIG -->|構成変更履歴| S3_AUDIT

    WAF_PROD -->|攻撃ブロック| SECHUB
    NFW_PROD -->|侵入検知| SECHUB

    GUARD -->|異常検知| EVENTBRIDGE
    SECHUB -->|重要度High| EVENTBRIDGE

    EVENTBRIDGE -->|自動調査| BEDROCK_SEC
    EVENTBRIDGE -->|アラート送信| SNS

    FLOWLOG -->|トラフィック分析| CLOUDWATCH
    CLOUDWATCH -->|閾値超過| SNS

    KMS_PROD -->|鍵使用ログ| TRAIL
    IAM_PROD -->|権限変更| CONFIG

    SG_PROD -.->|通信制御| RDS_ENC
    SG_PROD -.->|通信制御| S3_ENC

    PRIVLINK -.->|プライベート接続| RDS_ENC
    PRIVLINK -.->|プライベート接続| S3_ENC

    DIRECTCONNECT -.->|暗号化通信| NFW_PROD
    VPN_BACKUP -.->|バックアップ経路| NFW_PROD

    style SECHUB fill:#ff9999
    style GUARD fill:#ffcc99
    style WAF_PROD fill:#ff9999
    style NFW_PROD fill:#ff9999
    style KMS_PROD fill:#ffcc99
    style IAM_PROD fill:#99ccff
    style COGNITO fill:#99ccff
    style TRAIL fill:#cc99ff
    style CONFIG fill:#cc99ff
    style BEDROCK_SEC fill:#ff99cc
```

---

## 6. データフロー図

```mermaid
graph LR
    subgraph "職員端末"
        USER[職員<br/>1,300+ ユーザー]
    end

    subgraph "Direct Connect"
        DX[Direct Connect<br/>1Gbps × 2<br/>BGP冗長化]
    end

    subgraph "AWS Common Account"
        TGW[Transit Gateway]
        NFW[Network Firewall<br/>検査]
    end

    subgraph "Production VPC"
        CF[CloudFront<br/>キャッシュ]
        WAF[AWS WAF<br/>フィルタリング]
        ALB[ALB<br/>ロードバランシング]

        subgraph "ECS Fargate Cluster"
            ECS1[ECS Task 1]
            ECS2[ECS Task 2]
            ECS3[ECS Task 3]
            ECS4[ECS Task 4]
        end

        subgraph "データストア"
            REDIS[ElastiCache Redis<br/>セッション<br/>クエリキャッシュ]
            RDS_W[Aurora PostgreSQL<br/>Writer<br/>トランザクションデータ]
            RDS_R[Aurora PostgreSQL<br/>Reader<br/>参照クエリ]
            S3[S3 Bucket<br/>静的コンテンツ<br/>ファイルアップロード]
        end
    end

    subgraph "Operations Account"
        CW[CloudWatch Logs<br/>ログ集約]
        KINESIS[Kinesis Data Firehose<br/>ストリーミング]
        S3_LOGS[S3 Bucket<br/>長期保管<br/>Glacier移行]
        BEDROCK[Bedrock<br/>ログ分析]
    end

    subgraph "Audit Account"
        S3_AUDIT[S3 Bucket<br/>監査ログ<br/>10年保管]
    end

    USER -->|1. HTTPSリクエスト| DX
    DX -->|2. Direct Connect| TGW
    TGW -->|3. ルーティング| NFW
    NFW -->|4. 検査通過| CF
    CF -->|5. キャッシュヒット| USER
    CF -->|6. キャッシュミス| WAF
    WAF -->|7. フィルタリング| ALB
    ALB -->|8. ラウンドロビン| ECS1
    ALB -->|8. ラウンドロビン| ECS2
    ALB -->|8. ラウンドロビン| ECS3
    ALB -->|8. ラウンドロビン| ECS4

    ECS1 -->|9a. セッション取得| REDIS
    ECS1 -->|9b. 書き込みクエリ| RDS_W
    ECS1 -->|9c. 読み取りクエリ| RDS_R
    ECS1 -->|9d. ファイル取得| S3

    REDIS -->|10a. セッションデータ| ECS1
    RDS_W -->|10b. 書き込み結果| ECS1
    RDS_R -->|10c. 読み取り結果| ECS1
    S3 -->|10d. ファイルデータ| ECS1

    RDS_W -.->|レプリケーション| RDS_R

    ECS1 -->|11. レスポンス| ALB
    ALB -->|12. レスポンス| WAF
    WAF -->|13. レスポンス| CF
    CF -->|14. HTTPSレスポンス<br/>キャッシュ保存| USER

    ECS1 -->|ログ出力| CW
    ECS2 -->|ログ出力| CW
    ECS3 -->|ログ出力| CW
    ECS4 -->|ログ出力| CW

    CW -->|ストリーム| KINESIS
    KINESIS -->|バッチ書き込み| S3_LOGS
    S3_LOGS -.->|30日後| S3_LOGS

    CW -->|異常検知| BEDROCK
    BEDROCK -->|分析結果| CW

    RDS_W -.->|監査ログ| S3_AUDIT
    S3 -.->|アクセスログ| S3_AUDIT

    style USER fill:#e1f5ff
    style CF fill:#ff9999
    style WAF fill:#ffcc99
    style ALB fill:#99ccff
    style ECS1 fill:#99ff99
    style ECS2 fill:#99ff99
    style ECS3 fill:#99ff99
    style ECS4 fill:#99ff99
    style REDIS fill:#cc99ff
    style RDS_W fill:#ffcc99
    style RDS_R fill:#ffe6cc
    style BEDROCK fill:#ff99cc
```

---

## 7. DR構成図

```mermaid
graph TB
    subgraph "Primary Region - ap-northeast-1 (Tokyo)"
        subgraph "Production VPC - 10.1.0.0/16"
            ALB_PRI[Application Load Balancer<br/>Primary]

            subgraph "ECS Cluster - Primary"
                ECS_PRI1[ECS Task 1]
                ECS_PRI2[ECS Task 2]
                ECS_PRI3[ECS Task 3]
                ECS_PRI4[ECS Task 4]
            end

            subgraph "Aurora PostgreSQL - Primary"
                RDS_PRI_W[Writer Instance<br/>db.r6g.large<br/>ap-northeast-1a]
                RDS_PRI_R[Reader Instance<br/>db.r6g.large<br/>ap-northeast-1c]
            end

            subgraph "ElastiCache - Primary"
                REDIS_PRI[Redis Cluster<br/>4 Nodes<br/>cache.r6g.large]
            end

            S3_PRI[S3 Bucket - Primary<br/>アプリケーションデータ<br/>バージョニング有効]
        end

        BACKUP_PRI[AWS Backup Vault<br/>日次バックアップ<br/>保持期間: 90日]
    end

    subgraph "DR Region - ap-northeast-3 (Osaka)"
        subgraph "DR VPC - 10.3.0.0/16"
            ALB_DR[Application Load Balancer<br/>DR - Standby]

            subgraph "ECS Cluster - DR"
                ECS_DR1[ECS Task 1<br/>Warm Standby<br/>最小構成]
            end

            subgraph "Aurora PostgreSQL - DR"
                RDS_DR_R[Read Replica<br/>Cross-Region<br/>db.r6g.large<br/>ap-northeast-3a]
            end

            subgraph "ElastiCache - DR"
                REDIS_DR[Redis Cluster<br/>2 Nodes<br/>cache.r6g.large<br/>Warm Standby]
            end

            S3_DR[S3 Bucket - DR<br/>Cross-Region<br/>Replication<br/>レプリケーション先]
        end

        BACKUP_DR[AWS Backup Vault<br/>Cross-Region Copy<br/>保持期間: 90日]

        GLACIER_DR[S3 Glacier<br/>長期アーカイブ<br/>7年保管]
    end

    subgraph "Route 53 - DNS"
        R53[Route 53<br/>Health Check<br/>Failover Policy]
        R53_HC_PRI[Health Check<br/>Primary ALB]
        R53_HC_DR[Health Check<br/>DR ALB]
    end

    subgraph "監視・通知"
        CW_ALARM[CloudWatch Alarm<br/>Primary障害検知]
        SNS_DR[SNS Topic<br/>DR切替通知]
        EVENTBRIDGE[EventBridge<br/>自動フェイルオーバー<br/>トリガー]
    end

    R53 -->|Primary正常| R53_HC_PRI
    R53 -->|DR待機| R53_HC_DR
    R53_HC_PRI -->|ヘルスチェック| ALB_PRI
    R53_HC_DR -->|ヘルスチェック| ALB_DR

    ALB_PRI --> ECS_PRI1
    ALB_PRI --> ECS_PRI2
    ALB_PRI --> ECS_PRI3
    ALB_PRI --> ECS_PRI4

    ECS_PRI1 --> RDS_PRI_W
    ECS_PRI1 --> RDS_PRI_R
    ECS_PRI1 --> REDIS_PRI
    ECS_PRI1 --> S3_PRI

    RDS_PRI_W -.->|同期レプリケーション| RDS_PRI_R
    RDS_PRI_W ==>|非同期<br/>Cross-Region<br/>レプリケーション<br/>RPO: 数分| RDS_DR_R

    S3_PRI ==>|S3 Cross-Region<br/>Replication<br/>15分以内| S3_DR

    RDS_PRI_W -->|日次バックアップ| BACKUP_PRI
    BACKUP_PRI ==>|Cross-Region<br/>バックアップコピー| BACKUP_DR

    BACKUP_DR -.->|90日後| GLACIER_DR

    ALB_PRI -->|ヘルスチェック監視| CW_ALARM
    RDS_PRI_W -->|レプリケーション遅延監視| CW_ALARM

    CW_ALARM -->|障害検知| EVENTBRIDGE
    EVENTBRIDGE -->|自動フェイルオーバー| SNS_DR

    SNS_DR -.->|1. DNS切替指示| R53
    SNS_DR -.->|2. DR昇格指示| RDS_DR_R
    SNS_DR -.->|3. ECS増強指示| ECS_DR1

    R53 -.->|フェイルオーバー| ALB_DR
    ALB_DR -.->|トラフィック| ECS_DR1

    RDS_DR_R -.->|Promote to Writer<br/>RTO: 15分| ECS_DR1
    REDIS_DR -.->|スケールアウト| ECS_DR1

    style ALB_PRI fill:#99ff99
    style ECS_PRI1 fill:#99ff99
    style RDS_PRI_W fill:#ffcc99
    style REDIS_PRI fill:#cc99ff
    style S3_PRI fill:#99ccff
    style ALB_DR fill:#ffcccc
    style ECS_DR1 fill:#ffcccc
    style RDS_DR_R fill:#ffcccc
    style REDIS_DR fill:#ffcccc
    style S3_DR fill:#ffcccc
    style R53 fill:#ff9999
    style CW_ALARM fill:#ffcc99
    style EVENTBRIDGE fill:#ff99cc
```

---

## 災害復旧指標

### RPO (Recovery Point Objective) - 目標復旧時点

| サービス | RPO | レプリケーション方式 |
|---------|-----|-------------------|
| Aurora PostgreSQL | **5分以内** | Cross-Region 非同期レプリケーション |
| S3 バケット | **15分以内** | S3 Cross-Region Replication |
| AWS Backup | **24時間** | 日次バックアップの Cross-Region コピー |

### RTO (Recovery Time Objective) - 目標復旧時間

| フェイルオーバーシナリオ | RTO | 手順 |
|------------------------|-----|------|
| Route 53 DNS切替 | **5分** | Health Checkによる自動切替 |
| Aurora DR昇格 | **15分** | Read ReplicaをWriter Instanceに昇格 |
| ECS Fargate スケールアウト | **10分** | Desired Countを本番相当に増加 |
| **合計 RTO** | **30分以内** | 自動フェイルオーバー + 手動確認 |

---

## 構成図の凡例

| 色 | 意味 |
|----|------|
| 🟥 赤系 | 境界防御・CDN・DNS |
| 🟧 オレンジ系 | セキュリティサービス・暗号化 |
| 🟦 青系 | ネットワーク・ロードバランサー |
| 🟩 緑系 | アプリケーション・コンピューティング |
| 🟪 紫系 | キャッシュ・運用自動化 |
| ⬜ ピンク系 | 災害復旧・バックアップ |

| 線の種類 | 意味 |
|---------|------|
| 実線 `→` | データフロー・通信経路 |
| 点線 `-.->` | レプリケーション・バックアップ |
| 太線 `==>` | Cross-Region レプリケーション |

---

## 更新履歴

| 日付 | 版 | 更新内容 | 更新者 |
|------|---|---------|--------|
| 2025-11-05 | 1.0 | 初版作成 - 7種類のシステム構成図作成 | Claude |

---

**ドキュメント管理**
- ファイル名: `02_system_architecture_diagrams.md`
- 保存場所: `docs/02_design/basic/`
- 関連ドキュメント:
  - [01_aws_basic_design.md](01_aws_basic_design.md)
  - [../detailed/01_aws_detailed_design.md](../detailed/01_aws_detailed_design.md)
  - [../detailed/02_cloudformation_design.md](../detailed/02_cloudformation_design.md)
