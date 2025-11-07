# アカウント構成図

## AWS Organizations 構成図

```mermaid
graph TB
    Root[管理アカウント<br/>Root Account<br/>請求・Organizations管理]

    ProdOU[本番環境 OU<br/>Production OU]
    StagingOU[ステージング環境 OU<br/>Staging OU]

    ProdCommon[本番共通系アカウント<br/>niigata-kaigo-prod-common<br/>Transit Gateway/ログ集約]
    ProdApp[本番アプリ系アカウント<br/>niigata-kaigo-prod-app<br/>VPC: 10.1.0.0/16]

    StagingCommon[ステージング共通系アカウント<br/>niigata-kaigo-stg-common<br/>ログ集約]
    StagingApp[ステージングアプリ系アカウント<br/>niigata-kaigo-stg-app<br/>VPC: 10.2.0.0/16]

    Root --> ProdOU
    Root --> StagingOU

    ProdOU --> ProdCommon
    ProdOU --> ProdApp

    StagingOU --> StagingCommon
    StagingOU --> StagingApp

    style Root fill:#ff9999
    style ProdOU fill:#ffcc99
    style StagingOU fill:#99ccff
    style ProdCommon fill:#ffeb99
    style ProdApp fill:#ffeb99
    style StagingCommon fill:#99ddff
    style StagingApp fill:#99ddff
```

---

## アカウント間接続図（Transit Gateway）

```mermaid
graph TB
    subgraph "本番共通系アカウント"
        TGW[Transit Gateway<br/>ハブ]
        DXGW[Direct Connect Gateway]
        TGW -->|接続| DXGW
    end

    subgraph "本番アプリ系アカウント"
        ProdVPC[VPC<br/>10.1.0.0/16]
    end

    subgraph "ステージングアプリ系アカウント"
        StagingVPC[VPC<br/>10.2.0.0/16]
    end

    subgraph "オンプレミス"
        Office[新潟市庁舎<br/>192.168.0.0/16]
    end

    TGW -->|TGW Attachment| ProdVPC
    TGW -->|TGW Attachment| StagingVPC
    DXGW -->|Direct Connect<br/>100Mbps x 2回線| Office

    style TGW fill:#ffeb99
    style ProdVPC fill:#ffeb99
    style StagingVPC fill:#99ddff
    style Office fill:#cccccc
```

---

## ログ集約フロー

```mermaid
graph LR
    subgraph "本番アプリ系アカウント"
        ProdApp[ECS/RDS/ALB<br/>ログ生成]
    end

    subgraph "ステージングアプリ系アカウント"
        StagingApp[ECS/RDS/ALB<br/>ログ生成]
    end

    subgraph "本番共通系アカウント"
        CloudTrail[CloudTrail]
        CloudWatchLogs[CloudWatch Logs<br/>ログ集約]
        S3Logs[S3バケット<br/>長期保管]
        Config[AWS Config<br/>構成変更履歴]
    end

    ProdApp -->|ログ転送| CloudWatchLogs
    StagingApp -->|ログ転送| CloudWatchLogs

    CloudTrail -->|API操作ログ| S3Logs
    CloudWatchLogs -->|90日以降| S3Logs
    Config -->|構成履歴| S3Logs

    style CloudWatchLogs fill:#ffeb99
    style S3Logs fill:#ffeb99
```

---

## SCP適用範囲

```mermaid
graph TB
    Root[管理アカウント<br/>SCP: deny-root-account<br/>SCP: require-mfa<br/>SCP: deny-region-outside-tokyo-osaka]

    ProdOU[本番環境 OU<br/>SCP: deny-ebs-unencrypted<br/>SCP: deny-s3-public-access]
    StagingOU[ステージング環境 OU<br/>SCP: deny-ebs-unencrypted<br/>SCP: deny-s3-public-access]

    ProdCommon[本番共通系<br/>継承: 全SCP]
    ProdApp[本番アプリ系<br/>継承: 全SCP]

    StagingCommon[ステージング共通系<br/>継承: 全SCP]
    StagingApp[ステージングアプリ系<br/>継承: 全SCP]

    Root --> ProdOU
    Root --> StagingOU

    ProdOU --> ProdCommon
    ProdOU --> ProdApp

    StagingOU --> StagingCommon
    StagingOU --> StagingApp

    style Root fill:#ff9999
    style ProdOU fill:#ffcc99
    style StagingOU fill:#99ccff
```

---

## IAM ロール（クロスアカウントアクセス）

```mermaid
graph LR
    subgraph "管理アカウント"
        AdminUser[管理者]
    end

    subgraph "本番共通系アカウント"
        AuditRole1[監査ロール]
    end

    subgraph "本番アプリ系アカウント"
        AuditRole2[監査ロール]
        DevRole1[開発者ロール<br/>読み取り専用]
    end

    subgraph "ステージングアプリ系アカウント"
        DevRole2[開発者ロール<br/>フルアクセス]
    end

    AdminUser -->|AssumeRole| AuditRole1
    AdminUser -->|AssumeRole| AuditRole2

    DevRole2 -->|AssumeRole<br/>読み取り専用| DevRole1

    style AdminUser fill:#ff9999
    style AuditRole1 fill:#ffeb99
    style AuditRole2 fill:#ffeb99
    style DevRole2 fill:#99ddff
```

---

## 責務分離マトリクス

| リソース種別 | 管理アカウント | 本番共通系 | 本番アプリ系 | ステージング共通系 | ステージングアプリ系 |
|------------|-------------|----------|----------|----------------|-----------------|
| Organizations | ✅ | - | - | - | - |
| SCP | ✅ | - | - | - | - |
| 請求管理 | ✅ | - | - | - | - |
| Transit Gateway | - | ✅ | - | - | - |
| Direct Connect | - | ✅ | - | - | - |
| CloudTrail（集約） | - | ✅ | - | - | - |
| AWS Config（集約） | - | ✅ | - | - | - |
| VPC | - | - | ✅ | - | ✅ |
| ECS | - | - | ✅ | - | ✅ |
| RDS | - | - | ✅ | - | ✅ |
| S3（アプリデータ） | - | - | ✅ | - | ✅ |

---

## 環境別リソース比較

| リソース | 本番環境 | ステージング環境 |
|---------|---------|----------------|
| RDS | Multi-AZ、db.t3.medium | Single-AZ、db.t3.small |
| ECS | Fargate 2vCPU/4GB | Fargate 1vCPU/2GB |
| ElastiCache | cache.t3.medium | cache.t3.small |
| NAT Gateway | 2個（Multi-AZ） | 1個（Single-AZ） |
| Direct Connect | 共有 | 共有 |
| バックアップ保持期間 | 30日間 | 7日間 |

---

## 次のステップ

- [SCPポリシー例を確認](./scp_policies.json)
- [ネットワーク設計を確認](../03_network/)
