# データフロー図

## 目次
1. [全体データフロー](#全体データフロー)
2. [ユーザーリクエストフロー](#ユーザーリクエストフロー)
3. [バッチ処理フロー](#バッチ処理フロー)
4. [バックアップフロー](#バックアップフロー)
5. [ログフロー](#ログフロー)

---

## 全体データフロー

### システム全体のデータの流れ

```mermaid
graph TB
    USER[ユーザー<br/>Webブラウザ]

    subgraph "AWS Cloud (us-east-1)"
        CF[CloudFront<br/>(静的コンテンツ)]
        ALB[Application Load Balancer]
        ECS[ECS Fargate<br/>アプリケーション]
        RDS[RDS PostgreSQL<br/>マスターデータ]
        CACHE[ElastiCache Redis<br/>セッション・キャッシュ]
        EFS[EFS<br/>共有ファイル]
        S3_APP[S3<br/>アプリケーションログ]
        CW[CloudWatch Logs]
    end

    subgraph "DR環境 (us-west-2)"
        S3_DR[S3<br/>バックアップ]
    end

    USER -->|HTTPS| CF
    USER -->|HTTPS| ALB
    CF --> S3_STATIC[S3<br/>静的コンテンツ]
    ALB --> ECS
    ECS --> RDS
    ECS --> CACHE
    ECS --> EFS
    ECS --> S3_APP
    ECS --> CW

    S3_APP -.クロスリージョン<br/>レプリケーション.-> S3_DR

    style USER fill:#e1f5ff
    style ECS fill:#c7f5c7
    style RDS fill:#ffc7c7
    style S3_DR fill:#ffe1e1
```

---

## ユーザーリクエストフロー

### 認証ありリクエストフロー

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant ALB as Application<br/>Load Balancer
    participant ECS as ECS Fargate<br/>アプリケーション
    participant CACHE as ElastiCache<br/>Redis
    participant RDS as RDS<br/>PostgreSQL
    participant S3 as S3

    U->>ALB: HTTPS Request + Cookie
    ALB->>ECS: Forward Request
    ECS->>CACHE: セッション確認<br/>GET session:{id}
    CACHE-->>ECS: セッションデータ

    alt セッション有効
        ECS->>RDS: データ取得クエリ
        RDS-->>ECS: データ返却
        ECS->>CACHE: キャッシュ保存<br/>SET cache:{key}
        CACHE-->>ECS: OK
        ECS-->>ALB: Response (200 OK)
        ALB-->>U: HTTPS Response
    else セッション無効
        ECS-->>ALB: Response (401 Unauthorized)
        ALB-->>U: リダイレクト (ログイン画面)
    end

    Note over ECS,S3: ログ出力（非同期）
    ECS->>S3: アプリケーションログ
```

### データ登録フロー

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant ALB as ALB
    participant ECS as ECS Fargate
    participant CACHE as ElastiCache
    participant RDS as RDS
    participant CW as CloudWatch Logs

    U->>ALB: POST /api/users (JSON)
    ALB->>ECS: Forward Request

    ECS->>CACHE: セッション確認
    CACHE-->>ECS: セッションOK

    ECS->>ECS: バリデーション
    ECS->>RDS: BEGIN TRANSACTION
    RDS-->>ECS: OK

    ECS->>RDS: INSERT INTO users (...)
    RDS-->>ECS: OK (user_id=123)

    ECS->>RDS: INSERT INTO audit_log (...)
    RDS-->>ECS: OK

    ECS->>RDS: COMMIT
    RDS-->>ECS: OK

    ECS->>CACHE: キャッシュ削除<br/>DEL cache:users
    CACHE-->>ECS: OK

    ECS-->>ALB: Response (201 Created)
    ALB-->>U: HTTPS Response

    ECS->>CW: ログ出力<br/>(INFO: User created, id=123)
```

---

## バッチ処理フロー

### 日次集計バッチフロー

```mermaid
graph TB
    CRON[CloudWatch Events<br/>毎日 02:00 JST]
    LAMBDA[Lambda Function<br/>バッチ起動]
    ECS_BATCH[ECS Fargate<br/>バッチタスク]
    RDS[RDS PostgreSQL]
    S3_RESULT[S3<br/>集計結果]
    SNS[SNS Topic]
    EMAIL[Email通知]

    CRON -->|トリガー| LAMBDA
    LAMBDA -->|ECS RunTask| ECS_BATCH
    ECS_BATCH -->|データ取得| RDS
    RDS -->|データ返却| ECS_BATCH
    ECS_BATCH -->|集計| ECS_BATCH
    ECS_BATCH -->|結果出力| S3_RESULT
    ECS_BATCH -->|完了通知| SNS
    SNS -->|通知| EMAIL

    style CRON fill:#e1f5ff
    style ECS_BATCH fill:#c7f5c7
    style SNS fill:#ffe1e1
```

### バッチ処理詳細フロー

```mermaid
sequenceDiagram
    participant CW as CloudWatch Events
    participant LAMBDA as Lambda
    participant ECS as ECS Batch Task
    participant RDS as RDS
    participant S3 as S3
    participant SNS as SNS

    Note over CW: 毎日 02:00 JST
    CW->>LAMBDA: トリガー

    LAMBDA->>ECS: RunTask (バッチコンテナ起動)
    ECS->>ECS: 起動確認

    ECS->>RDS: データ取得クエリ<br/>SELECT * FROM orders WHERE date = yesterday
    RDS-->>ECS: データ返却 (1000件)

    ECS->>ECS: 集計処理<br/>(売上、ユーザー数等)

    ECS->>S3: 集計結果出力<br/>PUT reports/daily-summary-2025-01-15.json
    S3-->>ECS: OK

    ECS->>SNS: 完了通知<br/>(処理件数: 1000)
    SNS-->>ECS: OK

    ECS->>ECS: タスク終了
```

---

## バックアップフロー

### RDS自動バックアップフロー

```mermaid
graph TB
    CRON[CloudWatch Events<br/>毎日 03:00 JST]
    RDS[RDS PostgreSQL<br/>本番環境]
    SNAP[RDS Snapshot<br/>us-east-1]
    SNAP_DR[RDS Snapshot<br/>us-west-2]
    SNS[SNS Topic]
    EMAIL[Email通知]

    CRON -->|自動バックアップ開始| RDS
    RDS -->|スナップショット作成| SNAP
    SNAP -->|クロスリージョンコピー| SNAP_DR
    SNAP_DR -->|完了通知| SNS
    SNS -->|通知| EMAIL

    style CRON fill:#e1f5ff
    style SNAP fill:#c7f5c7
    style SNAP_DR fill:#ffe1e1
```

### S3クロスリージョンレプリケーションフロー

```mermaid
sequenceDiagram
    participant APP as Application
    participant S3_SRC as S3 Source<br/>(us-east-1)
    participant S3_DST as S3 Destination<br/>(us-west-2)
    participant CW as CloudWatch

    APP->>S3_SRC: PutObject (backup.zip)
    S3_SRC->>S3_SRC: 暗号化 (KMS)
    S3_SRC->>S3_SRC: バージョニング (v1)

    S3_SRC->>S3_DST: レプリケーション開始
    S3_DST->>S3_DST: 暗号化 (KMS)
    S3_DST->>S3_DST: バージョニング (v1)

    S3_DST-->>S3_SRC: レプリケーション完了
    S3_SRC->>CW: メトリクス送信<br/>(ReplicationLatency)

    Note over S3_SRC,S3_DST: レプリケーション時間: 平均5分
```

---

## ログフロー

### アプリケーションログフロー

```mermaid
graph TB
    ECS[ECS Fargate<br/>アプリケーション]
    CW_LOGS[CloudWatch Logs<br/>/ecs/kaigo-subsys-prod]
    S3_LOGS[S3<br/>kaigo-subsys-prod-app-logs]
    S3_ARCHIVE[S3 Glacier<br/>長期保管]

    ECS -->|ログ出力<br/>(STDOUT/STDERR)| CW_LOGS
    CW_LOGS -->|エクスポート<br/>(日次)| S3_LOGS
    S3_LOGS -->|ライフサイクル<br/>(90日後)| S3_ARCHIVE

    style ECS fill:#c7f5c7
    style CW_LOGS fill:#e1f5ff
    style S3_ARCHIVE fill:#fff4e1
```

### 監査ログフロー

```mermaid
graph TB
    subgraph "ログソース"
        CT[CloudTrail<br/>API操作ログ]
        VPC[VPC Flow Logs<br/>ネットワークログ]
        ALB_LOG[ALB Access Logs]
        WAF_LOG[WAF Logs]
    end

    subgraph "ログ保存"
        S3_AUDIT[S3<br/>kaigo-subsys-prod-audit-logs]
        CW_LOGS[CloudWatch Logs]
    end

    subgraph "長期保管"
        S3_GLACIER[S3 Glacier<br/>7年保管]
    end

    CT --> S3_AUDIT
    VPC --> CW_LOGS
    ALB_LOG --> S3_AUDIT
    WAF_LOG --> S3_AUDIT

    S3_AUDIT -->|ライフサイクル<br/>(365日後)| S3_GLACIER

    style S3_AUDIT fill:#ffe1e1
    style S3_GLACIER fill:#fff4e1
```

### リアルタイムログ監視フロー

```mermaid
sequenceDiagram
    participant ECS as ECS Fargate
    participant CW_LOGS as CloudWatch Logs
    participant CW_ALARM as CloudWatch Alarms
    participant SNS as SNS Topic
    participant SLACK as Slack
    participant OPS as 運用担当者

    ECS->>CW_LOGS: ERROR ログ出力
    CW_LOGS->>CW_LOGS: メトリクスフィルタ適用<br/>(ERROR|FATAL count)

    alt エラー数が閾値超過
        CW_LOGS->>CW_ALARM: メトリクス送信<br/>(ErrorCount > 10)
        CW_ALARM->>CW_ALARM: アラーム状態に変更
        CW_ALARM->>SNS: アラーム通知
        SNS->>SLACK: Webhook送信
        SNS->>OPS: Email送信
        OPS->>OPS: ログ確認・対応
    end
```

---

## データ暗号化フロー

### データ保存時の暗号化

```mermaid
graph TB
    APP[Application]

    subgraph "暗号化"
        KMS[AWS KMS<br/>カスタマーマネージドキー]
    end

    subgraph "データストア"
        RDS[RDS PostgreSQL<br/>AES-256暗号化]
        CACHE[ElastiCache Redis<br/>AES-256暗号化]
        S3[S3<br/>SSE-KMS暗号化]
        EFS[EFS<br/>AES-256暗号化]
    end

    APP -->|データ書き込み| RDS
    APP -->|データ書き込み| CACHE
    APP -->|データ書き込み| S3
    APP -->|データ書き込み| EFS

    RDS -->|暗号化キー取得| KMS
    CACHE -->|暗号化キー取得| KMS
    S3 -->|暗号化キー取得| KMS
    EFS -->|暗号化キー取得| KMS

    style KMS fill:#ffe1e1
    style RDS fill:#ffc7c7
    style S3 fill:#e1f5ff
```

### 通信時の暗号化

```mermaid
graph TB
    USER[ユーザー]
    CF[CloudFront<br/>TLS 1.2以上]
    ALB[ALB<br/>TLS 1.2以上]
    ECS[ECS Fargate]

    subgraph "AWS内部"
        RDS[RDS<br/>SSL/TLS接続]
        CACHE[ElastiCache<br/>TLS暗号化]
        S3[S3<br/>HTTPS]
    end

    USER -->|HTTPS| CF
    USER -->|HTTPS| ALB
    CF -->|HTTPS| S3
    ALB -->|HTTPS| ECS
    ECS -->|SSL/TLS| RDS
    ECS -->|TLS| CACHE
    ECS -->|HTTPS| S3

    style USER fill:#e1f5ff
    style CF fill:#c7f5c7
    style ALB fill:#c7f5c7
```

---

## 関連ドキュメント

- [システム構成図](./system_architecture.md)
- [ネットワーク図](./network_diagram.md)
- [バックアップ・DR設計](../09_backup_dr/backup_dr_design.md)
- [セキュリティ設計](../07_security/security_design.md)

---

**作成日**: 2025-11-05
**作成者**: Architect
**バージョン**: 1.0
