# 全体構成図

## システム全体構成（本番環境）

```mermaid
graph TB
    subgraph "新潟市庁舎（オンプレミス）"
        Users[職員ユーザー<br/>1,300名]
        OfficeNetwork[庁舎ネットワーク<br/>192.168.0.0/16]
        Users --> OfficeNetwork
    end

    subgraph "AWS - 本番共通系アカウント"
        DX1[Direct Connect<br/>100Mbps 回線1]
        DX2[Direct Connect<br/>100Mbps 回線2]
        TGW[Transit Gateway<br/>ハブ]
        CloudTrail[CloudTrail<br/>監査ログ]
        CloudWatchLogs[CloudWatch Logs<br/>ログ集約]
        Config[AWS Config<br/>構成履歴]
        S3Logs[S3バケット<br/>ログ長期保管]

        DX1 --> TGW
        DX2 --> TGW
        CloudTrail --> S3Logs
        CloudWatchLogs --> S3Logs
        Config --> S3Logs
    end

    subgraph "AWS - 本番アプリ系アカウント"
        subgraph "VPC 10.1.0.0/16"
            subgraph "Public Subnet（2AZ）"
                IGW[Internet Gateway]
                NAT1[NAT Gateway 1a]
                NAT2[NAT Gateway 1c]
                ALB[Application<br/>Load Balancer]

                IGW --> NAT1
                IGW --> NAT2
            end

            subgraph "Private App Subnet（2AZ）"
                ECS1[ECS Fargate<br/>Task 1]
                ECS2[ECS Fargate<br/>Task 2]
                ECS3[ECS Fargate<br/>Task 3]
            end

            subgraph "Private DB Subnet（2AZ）"
                RDS[(RDS MySQL<br/>Multi-AZ)]
            end

            subgraph "Private Cache Subnet（2AZ）"
                Redis[(ElastiCache<br/>Redis)]
            end

            ALB --> ECS1
            ALB --> ECS2
            ALB --> ECS3

            ECS1 --> RDS
            ECS2 --> RDS
            ECS3 --> RDS

            ECS1 --> Redis
            ECS2 --> Redis
            ECS3 --> Redis
        end

        WAF[AWS WAF<br/>OWASP Top 10]
        Cognito[Cognito<br/>User Pool + MFA]
        S3App[S3バケット<br/>ドキュメント保管]
        CloudFront[CloudFront<br/>CDN]
        KMS[AWS KMS<br/>暗号化キー]

        WAF --> ALB
        Cognito --> ECS1
        ECS1 --> S3App
        CloudFront --> S3App

        RDS -.暗号化.- KMS
        S3App -.暗号化.- KMS
    end

    subgraph "DR環境（大阪リージョン）"
        S3DR[S3バケット<br/>レプリケーション]
        RDSDR[(RDSスナップショット<br/>日次コピー)]

        S3App -.レプリケーション.- S3DR
        RDS -.スナップショット.- RDSDR
    end

    OfficeNetwork --> DX1
    OfficeNetwork --> DX2
    TGW --> ALB

    style Users fill:#cccccc
    style TGW fill:#ffeb99
    style ALB fill:#ffeb99
    style ECS1 fill:#ffeb99
    style RDS fill:#ffeb99
    style S3Logs fill:#ffeb99
    style CloudTrail fill:#ffeb99
```

---

## レイヤー別構成図

```mermaid
graph TB
    subgraph "エッジレイヤー"
        CF[CloudFront<br/>CDN]
        WAF[AWS WAF<br/>Web Application Firewall]
    end

    subgraph "ロードバランサーレイヤー"
        ALB[Application Load Balancer<br/>HTTPS終端]
    end

    subgraph "アプリケーションレイヤー"
        ECS[ECS Fargate<br/>コンテナ実行]
        Cognito[Cognito<br/>認証]
    end

    subgraph "データレイヤー"
        RDS[(RDS MySQL<br/>Multi-AZ)]
        Redis[(ElastiCache Redis<br/>セッション管理)]
        S3[S3バケット<br/>ドキュメント保管]
    end

    subgraph "ネットワークレイヤー"
        TGW[Transit Gateway<br/>アカウント間接続]
        DX[Direct Connect<br/>オンプレミス接続]
    end

    subgraph "監視・ログレイヤー"
        CloudWatch[CloudWatch<br/>メトリクス・アラーム]
        CloudTrail[CloudTrail<br/>API操作ログ]
        Config[AWS Config<br/>構成変更履歴]
    end

    CF --> WAF
    WAF --> ALB
    ALB --> ECS
    ECS --> Cognito
    ECS --> RDS
    ECS --> Redis
    ECS --> S3

    TGW --> ALB
    DX --> TGW

    CloudWatch --> ECS
    CloudWatch --> RDS
    CloudTrail -.監査.- ECS
    Config -.構成.- RDS

    style CF fill:#d1ecf1
    style WAF fill:#fff3cd
    style ALB fill:#d1ecf1
    style ECS fill:#d1ecf1
    style RDS fill:#d4edda
    style TGW fill:#ffeb99
```

---

## コンポーネント相互関係図

```mermaid
graph LR
    subgraph "ユーザー"
        User[庁舎職員]
    end

    subgraph "認証"
        Cognito[Cognito<br/>User Pool]
    end

    subgraph "フロントエンド"
        CloudFront[CloudFront]
        S3Static[S3<br/>静的コンテンツ]
    end

    subgraph "バックエンド"
        ALB[ALB]
        ECS[ECS Fargate<br/>アプリケーション]
    end

    subgraph "データストア"
        RDS[(RDS MySQL<br/>永続データ)]
        Redis[(ElastiCache<br/>セッション・キャッシュ)]
        S3Data[S3<br/>ドキュメント]
    end

    subgraph "ネットワーク"
        TGW[Transit Gateway]
        DX[Direct Connect]
    end

    User -->|1. 認証| Cognito
    User -->|2. 静的コンテンツ| CloudFront
    CloudFront --> S3Static
    User -->|3. API| DX
    DX --> TGW
    TGW --> ALB
    ALB -->|4. リクエスト転送| ECS
    ECS -->|5. セッション確認| Redis
    ECS -->|6. データ取得| RDS
    ECS -->|7. ドキュメント取得| S3Data

    style Cognito fill:#fff3cd
    style CloudFront fill:#d1ecf1
    style ECS fill:#d1ecf1
    style RDS fill:#d4edda
```

---

## 可用性構成図

```mermaid
graph TB
    subgraph "AZ 1a"
        NAT1a[NAT Gateway 1a]
        ALB1a[ALB Node 1a]
        ECS1a[ECS Task 1a]
        RDSPrimary[(RDS Primary)]
        Redis1a[(Redis Primary)]
    end

    subgraph "AZ 1c"
        NAT1c[NAT Gateway 1c]
        ALB1c[ALB Node 1c]
        ECS1c[ECS Task 1c]
        RDSStandby[(RDS Standby<br/>同期レプリケーション)]
        Redis1c[(Redis Replica)]
    end

    Users[ユーザー]
    DX[Direct Connect<br/>100Mbps × 2回線]

    Users --> DX
    DX --> ALB1a
    DX --> ALB1c

    ALB1a --> ECS1a
    ALB1c --> ECS1c

    ECS1a --> RDSPrimary
    ECS1c --> RDSPrimary

    ECS1a --> Redis1a
    ECS1c --> Redis1a

    RDSPrimary -.同期レプリケーション.- RDSStandby
    Redis1a -.非同期レプリケーション.- Redis1c

    style RDSPrimary fill:#d4edda
    style RDSStandby fill:#d4edda,stroke-dasharray: 5 5
    style Redis1a fill:#d4edda
    style Redis1c fill:#d4edda,stroke-dasharray: 5 5
```

---

## セキュリティ構成図

```mermaid
graph TB
    subgraph "外部"
        User[ユーザー]
    end

    subgraph "セキュリティレイヤー1: エッジ"
        WAF[AWS WAF<br/>OWASP Top 10対策]
        Shield[AWS Shield<br/>DDoS対策]
    end

    subgraph "セキュリティレイヤー2: ネットワーク"
        NACL[Network ACL<br/>サブネット境界]
        SG[Security Groups<br/>最小権限ルール]
    end

    subgraph "セキュリティレイヤー3: アプリケーション"
        Cognito[Cognito + MFA<br/>多要素認証]
        IAM[IAMロール<br/>最小権限]
    end

    subgraph "セキュリティレイヤー4: データ"
        KMS[AWS KMS<br/>暗号化キー管理]
        TLS[TLS 1.3<br/>転送時暗号化]
        Encryption[AES-256<br/>保管時暗号化]
    end

    subgraph "監査"
        CloudTrail[CloudTrail<br/>API操作ログ]
        GuardDuty[GuardDuty<br/>脅威検知]
        Config[AWS Config<br/>構成変更]
    end

    User --> WAF
    WAF --> Shield
    Shield --> NACL
    NACL --> SG
    SG --> Cognito
    Cognito --> IAM

    IAM --> KMS
    KMS --> TLS
    TLS --> Encryption

    CloudTrail -.監査.- IAM
    GuardDuty -.脅威検知.- SG
    Config -.構成確認.- Encryption

    style WAF fill:#fff3cd
    style Shield fill:#fff3cd
    style Cognito fill:#fff3cd
    style KMS fill:#fff3cd
    style CloudTrail fill:#f8d7da
```

---

## DR構成図

```mermaid
graph TB
    subgraph "東京リージョン（本番）"
        TokyoVPC[VPC 10.1.0.0/16]
        TokyoECS[ECS Fargate]
        TokyoRDS[(RDS MySQL<br/>Multi-AZ)]
        TokyoS3[S3バケット]
        TokyoCFN[CloudFormation<br/>テンプレート]
    end

    subgraph "大阪リージョン（DR）"
        OsakaVPC[VPC 10.1.0.0/16<br/>未作成]
        OsakaRDS[(RDSスナップショット<br/>日次コピー)]
        OsakaS3[S3バケット<br/>レプリケーション]
        OsakaCFN[CloudFormation<br/>テンプレート]
    end

    subgraph "GitHub（IaCリポジトリ）"
        GitHub[CloudFormation<br/>テンプレート]
    end

    TokyoRDS -.日次スナップショット.- OsakaRDS
    TokyoS3 -.クロスリージョン<br/>レプリケーション.- OsakaS3
    TokyoCFN -.Git管理.- GitHub
    GitHub -.DR時デプロイ.- OsakaCFN

    DR[災害発生]
    DR -->|1. CloudFormation実行| OsakaVPC
    DR -->|2. RDSスナップショット復元| OsakaRDS
    DR -->|3. S3レプリカ参照| OsakaS3

    style TokyoRDS fill:#d4edda
    style OsakaRDS fill:#f8d7da,stroke-dasharray: 5 5
    style TokyoS3 fill:#d1ecf1
    style OsakaS3 fill:#f8d7da,stroke-dasharray: 5 5
```

---

## 次のステップ

- [ネットワーク詳細図を確認](./network_diagram.md)
- [データフロー図を確認](./dataflow_diagram.md)
