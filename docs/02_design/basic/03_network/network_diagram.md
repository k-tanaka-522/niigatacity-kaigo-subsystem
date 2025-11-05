# ネットワーク構成図

## 概要

このドキュメントでは、新潟市介護保険サブシステムのネットワーク構成を図で示します。

---

## 全体ネットワーク構成図

```mermaid
graph TB
    subgraph Internet["インターネット"]
        User[ユーザー]
    end

    subgraph CloudFront["CloudFront Distribution"]
        CF[CloudFront<br/>静的コンテンツ配信]
    end

    subgraph "東京リージョン (ap-northeast-1)"
        subgraph "VPC (10.0.0.0/16)"
            subgraph "AZ-A (ap-northeast-1a)"
                subgraph "Public Subnet A (10.0.1.0/24)"
                    NATGW_A[NAT Gateway A]
                    ALB_A[ALB Primary]
                end
                subgraph "Private Subnet A (10.0.11.0/24)"
                    ECS_A[ECS Fargate<br/>Task A]
                    RDS_PRIMARY[(RDS MySQL<br/>Primary)]
                end
                subgraph "Data Subnet A (10.0.21.0/24)"
                    REDIS_A[ElastiCache<br/>Redis Primary]
                end
            end

            subgraph "AZ-C (ap-northeast-1c)"
                subgraph "Public Subnet C (10.0.2.0/24)"
                    NATGW_C[NAT Gateway C]
                    ALB_C[ALB Secondary]
                end
                subgraph "Private Subnet C (10.0.12.0/24)"
                    ECS_C[ECS Fargate<br/>Task C]
                    RDS_STANDBY[(RDS MySQL<br/>Standby)]
                end
                subgraph "Data Subnet C (10.0.22.0/24)"
                    REDIS_C[ElastiCache<br/>Redis Replica]
                end
            end

            IGW[Internet Gateway]
        end
    end

    subgraph "S3"
        S3_STATIC[S3 Bucket<br/>静的ファイル]
        S3_LOG[S3 Bucket<br/>ログ保管]
        S3_BACKUP[S3 Bucket<br/>バックアップ]
    end

    subgraph "基幹システム（既存）"
        LEGACY[介護保険<br/>基幹システム]
    end

    User -->|HTTPS| CF
    CF -->|Origin Request| S3_STATIC
    User -->|HTTPS| ALB_A
    User -->|HTTPS| ALB_C

    ALB_A --> ECS_A
    ALB_C --> ECS_C

    ECS_A --> RDS_PRIMARY
    ECS_C --> RDS_PRIMARY
    RDS_PRIMARY -.->|同期レプリケーション| RDS_STANDBY

    ECS_A --> REDIS_A
    ECS_C --> REDIS_A
    REDIS_A -.->|非同期レプリケーション| REDIS_C

    ECS_A -->|VPN/Direct Connect| LEGACY
    ECS_C -->|VPN/Direct Connect| LEGACY

    ECS_A -->|Internet via NAT| NATGW_A
    ECS_C -->|Internet via NAT| NATGW_C
    NATGW_A --> IGW
    NATGW_C --> IGW
    IGW --> Internet

    ECS_A -.->|ログ出力| S3_LOG
    RDS_PRIMARY -.->|自動バックアップ| S3_BACKUP

    style User fill:#e1f5ff
    style CF fill:#ff9900
    style ALB_A fill:#ff6600
    style ALB_C fill:#ff6600
    style ECS_A fill:#ff9900
    style ECS_C fill:#ff9900
    style RDS_PRIMARY fill:#3b48cc
    style RDS_STANDBY fill:#3b48cc
    style REDIS_A fill:#d62828
    style REDIS_C fill:#d62828
    style S3_STATIC fill:#569a31
    style S3_LOG fill:#569a31
    style S3_BACKUP fill:#569a31
    style NATGW_A fill:#ff9900
    style NATGW_C fill:#ff9900
    style IGW fill:#ff9900
    style LEGACY fill:#cccccc
```

---

## VPC CIDR とサブネット構成

```mermaid
graph TB
    subgraph VPC["VPC: 10.0.0.0/16"]
        subgraph AZ_A["AZ-A (ap-northeast-1a)"]
            PUBLIC_A["Public Subnet A<br/>10.0.1.0/24<br/>(254 IPs)"]
            PRIVATE_A["Private Subnet A<br/>10.0.11.0/24<br/>(254 IPs)"]
            DATA_A["Data Subnet A<br/>10.0.21.0/24<br/>(254 IPs)"]
        end

        subgraph AZ_C["AZ-C (ap-northeast-1c)"]
            PUBLIC_C["Public Subnet C<br/>10.0.2.0/24<br/>(254 IPs)"]
            PRIVATE_C["Private Subnet C<br/>10.0.12.0/24<br/>(254 IPs)"]
            DATA_C["Data Subnet C<br/>10.0.22.0/24<br/>(254 IPs)"]
        end

        RESERVED["予約済みCIDR<br/>10.0.3.0/24 ～ 10.0.10.0/24<br/>(将来の拡張用)"]
    end

    style PUBLIC_A fill:#e1f5ff
    style PUBLIC_C fill:#e1f5ff
    style PRIVATE_A fill:#ffe1e1
    style PRIVATE_C fill:#ffe1e1
    style DATA_A fill:#e1ffe1
    style DATA_C fill:#e1ffe1
    style RESERVED fill:#f0f0f0
```

---

## ルーティング構成

### Public Subnet のルートテーブル

```mermaid
graph LR
    PUBLIC_RT[Public Route Table]
    LOCAL["10.0.0.0/16<br/>(local)"]
    IGW_ROUTE["0.0.0.0/0<br/>(Internet Gateway)"]
    LEGACY_ROUTE["172.16.0.0/12<br/>(VPN/Direct Connect)"]

    PUBLIC_RT --> LOCAL
    PUBLIC_RT --> IGW_ROUTE
    PUBLIC_RT --> LEGACY_ROUTE
```

| Destination | Target | 用途 |
|------------|--------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | igw-xxxxx | インターネット通信 |
| 172.16.0.0/12 | vgw-xxxxx | 基幹システム通信 |

### Private Subnet のルートテーブル（AZ-A）

```mermaid
graph LR
    PRIVATE_RT_A[Private Route Table A]
    LOCAL_A["10.0.0.0/16<br/>(local)"]
    NAT_A["0.0.0.0/0<br/>(NAT Gateway A)"]
    LEGACY_A["172.16.0.0/12<br/>(VPN/Direct Connect)"]

    PRIVATE_RT_A --> LOCAL_A
    PRIVATE_RT_A --> NAT_A
    PRIVATE_RT_A --> LEGACY_A
```

| Destination | Target | 用途 |
|------------|--------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | nat-xxxxx (AZ-A) | インターネット通信（Egress） |
| 172.16.0.0/12 | vgw-xxxxx | 基幹システム通信 |

### Private Subnet のルートテーブル（AZ-C）

```mermaid
graph LR
    PRIVATE_RT_C[Private Route Table C]
    LOCAL_C["10.0.0.0/16<br/>(local)"]
    NAT_C["0.0.0.0/0<br/>(NAT Gateway C)"]
    LEGACY_C["172.16.0.0/12<br/>(VPN/Direct Connect)"]

    PRIVATE_RT_C --> LOCAL_C
    PRIVATE_RT_C --> NAT_C
    PRIVATE_RT_C --> LEGACY_C
```

| Destination | Target | 用途 |
|------------|--------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 0.0.0.0/0 | nat-xxxxx (AZ-C) | インターネット通信（Egress） |
| 172.16.0.0/12 | vgw-xxxxx | 基幹システム通信 |

### Data Subnet のルートテーブル

```mermaid
graph LR
    DATA_RT[Data Route Table]
    LOCAL_DATA["10.0.0.0/16<br/>(local)"]
    LEGACY_DATA["172.16.0.0/12<br/>(VPN/Direct Connect)"]

    DATA_RT --> LOCAL_DATA
    DATA_RT --> LEGACY_DATA
```

| Destination | Target | 用途 |
|------------|--------|------|
| 10.0.0.0/16 | local | VPC内通信 |
| 172.16.0.0/12 | vgw-xxxxx | 基幹システム通信（必要な場合） |

**注意**: Data Subnetはインターネットへの直接アクセスを持たない（セキュリティ強化）

---

## セキュリティグループの通信フロー

```mermaid
graph TB
    Internet[インターネット]
    ALB_SG[ALB Security Group]
    ECS_SG[ECS Security Group]
    RDS_SG[RDS Security Group]
    REDIS_SG[ElastiCache Security Group]

    Internet -->|HTTPS:443| ALB_SG
    ALB_SG -->|HTTP:8080| ECS_SG
    ECS_SG -->|MySQL:3306| RDS_SG
    ECS_SG -->|Redis:6379| REDIS_SG

    style Internet fill:#e1f5ff
    style ALB_SG fill:#ff6600
    style ECS_SG fill:#ff9900
    style RDS_SG fill:#3b48cc
    style REDIS_SG fill:#d62828
```

### 通信許可ルール

| Source | Destination | Protocol | Port | 説明 |
|--------|-------------|----------|------|------|
| 0.0.0.0/0 | ALB | TCP | 443 | インターネットからのHTTPS |
| ALB SG | ECS SG | TCP | 8080 | ALBからECSへのHTTP |
| ECS SG | RDS SG | TCP | 3306 | ECSからRDSへのMySQL |
| ECS SG | ElastiCache SG | TCP | 6379 | ECSからRedisへのアクセス |
| ECS SG | 0.0.0.0/0 | TCP | 443 | ECSから外部APIへのHTTPS |

---

## VPN / Direct Connect 構成（基幹システム連携）

```mermaid
graph TB
    subgraph AWS["AWS (ap-northeast-1)"]
        VPC[VPC<br/>10.0.0.0/16]
        VGW[Virtual Private Gateway]
        CGW[Customer Gateway]
    end

    subgraph OnPremises["オンプレミス（新潟市）"]
        DATACENTER[データセンター<br/>172.16.0.0/12]
        FW[ファイアウォール]
        LEGACY_SYS[基幹システム]
    end

    VPC --> VGW
    VGW <-->|VPN Tunnel<br/>or<br/>Direct Connect| CGW
    CGW --> FW
    FW --> DATACENTER
    DATACENTER --> LEGACY_SYS

    style VPC fill:#ff9900
    style VGW fill:#ff6600
    style CGW fill:#ff6600
    style DATACENTER fill:#cccccc
    style FW fill:#d62828
    style LEGACY_SYS fill:#cccccc
```

### VPN接続パラメータ（仮値）

| パラメータ | 値 |
|----------|-----|
| VPN接続タイプ | Site-to-Site VPN |
| ルーティング | Dynamic (BGP) |
| トンネル冗長化 | 2つのトンネル（Active/Standby） |
| 暗号化 | AES-256 |
| IKE バージョン | IKEv2 |
| オンプレミスCIDR | 172.16.0.0/12 |
| AWS CIDR | 10.0.0.0/16 |

---

## ネットワークACL（NACL）構成

### Public Subnet NACL

**Inbound Rules**

| Rule # | Type | Protocol | Port Range | Source | Allow/Deny |
|--------|------|----------|-----------|--------|------------|
| 100 | HTTPS | TCP | 443 | 0.0.0.0/0 | ALLOW |
| 110 | HTTP | TCP | 80 | 0.0.0.0/0 | ALLOW |
| 120 | Ephemeral | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All | All | All | 0.0.0.0/0 | DENY |

**Outbound Rules**

| Rule # | Type | Protocol | Port Range | Destination | Allow/Deny |
|--------|------|----------|-----------|-------------|------------|
| 100 | HTTP | TCP | 80 | 0.0.0.0/0 | ALLOW |
| 110 | HTTPS | TCP | 443 | 0.0.0.0/0 | ALLOW |
| 120 | Ephemeral | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All | All | All | 0.0.0.0/0 | DENY |

### Private Subnet NACL

**Inbound Rules**

| Rule # | Type | Protocol | Port Range | Source | Allow/Deny |
|--------|------|----------|-----------|--------|------------|
| 100 | Custom TCP | TCP | 8080 | 10.0.1.0/24 | ALLOW |
| 110 | Custom TCP | TCP | 8080 | 10.0.2.0/24 | ALLOW |
| 120 | Ephemeral | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All | All | All | 0.0.0.0/0 | DENY |

**Outbound Rules**

| Rule # | Type | Protocol | Port Range | Destination | Allow/Deny |
|--------|------|----------|-----------|-------------|------------|
| 100 | MySQL | TCP | 3306 | 10.0.21.0/24 | ALLOW |
| 110 | MySQL | TCP | 3306 | 10.0.22.0/24 | ALLOW |
| 120 | Redis | TCP | 6379 | 10.0.21.0/24 | ALLOW |
| 130 | Redis | TCP | 6379 | 10.0.22.0/24 | ALLOW |
| 140 | HTTPS | TCP | 443 | 0.0.0.0/0 | ALLOW |
| 150 | Ephemeral | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All | All | All | 0.0.0.0/0 | DENY |

### Data Subnet NACL

**Inbound Rules**

| Rule # | Type | Protocol | Port Range | Source | Allow/Deny |
|--------|------|----------|-----------|--------|------------|
| 100 | MySQL | TCP | 3306 | 10.0.11.0/24 | ALLOW |
| 110 | MySQL | TCP | 3306 | 10.0.12.0/24 | ALLOW |
| 120 | Redis | TCP | 6379 | 10.0.11.0/24 | ALLOW |
| 130 | Redis | TCP | 6379 | 10.0.12.0/24 | ALLOW |
| * | All | All | All | 0.0.0.0/0 | DENY |

**Outbound Rules**

| Rule # | Type | Protocol | Port Range | Destination | Allow/Deny |
|--------|------|----------|-----------|-------------|------------|
| 100 | Ephemeral | TCP | 1024-65535 | 10.0.11.0/24 | ALLOW |
| 110 | Ephemeral | TCP | 1024-65535 | 10.0.12.0/24 | ALLOW |
| 120 | MySQL Replication | TCP | 3306 | 10.0.22.0/24 | ALLOW |
| 130 | Redis Replication | TCP | 6379 | 10.0.22.0/24 | ALLOW |
| * | All | All | All | 0.0.0.0/0 | DENY |

---

## DNS構成

```mermaid
graph TB
    Route53[Route 53<br/>Hosted Zone]
    ALB_DNS[ALB DNS Name]
    CF_DNS[CloudFront DNS Name]

    PUBLIC_DOMAIN["kaigo.niigata.lg.jp"]
    API_DOMAIN["api.kaigo.niigata.lg.jp"]
    STATIC_DOMAIN["static.kaigo.niigata.lg.jp"]

    PUBLIC_DOMAIN --> Route53
    Route53 --> API_DOMAIN
    Route53 --> STATIC_DOMAIN
    API_DOMAIN --> ALB_DNS
    STATIC_DOMAIN --> CF_DNS

    style Route53 fill:#ff9900
    style PUBLIC_DOMAIN fill:#e1f5ff
    style API_DOMAIN fill:#e1f5ff
    style STATIC_DOMAIN fill:#e1f5ff
```

### Route 53 レコード

| Name | Type | Value | TTL |
|------|------|-------|-----|
| kaigo.niigata.lg.jp | A | Alias to CloudFront | 300 |
| api.kaigo.niigata.lg.jp | A | Alias to ALB | 60 |
| static.kaigo.niigata.lg.jp | A | Alias to CloudFront | 3600 |

---

## ネットワーク帯域とスループット

### 想定トラフィック

| 項目 | ピーク時 | 平均 |
|------|---------|------|
| ユーザーリクエスト | 1,000 req/min | 300 req/min |
| ALB → ECS トラフィック | 50 Mbps | 15 Mbps |
| ECS → RDS トラフィック | 20 Mbps | 5 Mbps |
| CloudFront → S3 トラフィック | 100 Mbps | 30 Mbps |

### NAT Gateway 構成

| AZ | NAT Gateway | 帯域 | 備考 |
|----|-------------|------|------|
| ap-northeast-1a | NAT Gateway A | 最大5 Gbps | ECS Egress通信用 |
| ap-northeast-1c | NAT Gateway C | 最大5 Gbps | ECS Egress通信用 |

**冗長化**: 各AZに独立したNAT Gatewayを配置し、片方のAZ障害時も通信継続

---

## ネットワーク監視

### CloudWatch メトリクス

| リソース | メトリクス | 閾値 |
|---------|----------|------|
| NAT Gateway | BytesOutToDestination | 1 GB/5min（警告） |
| NAT Gateway | PacketsDropCount | 100 packets/min（警告） |
| VPN Connection | TunnelState | 1つでもDOWN（重大） |
| ALB | ActiveConnectionCount | 1,000（警告） |

### VPC Flow Logs

| 項目 | 設定値 |
|------|-------|
| 対象 | VPC全体 |
| フィルター | すべてのトラフィック（ACCEPT/REJECT） |
| 保存先 | CloudWatch Logs |
| 保管期間 | 90日 |
| 分析ツール | CloudWatch Logs Insights |

---

## セキュリティ考慮事項

### ネットワークセキュリティ

1. **最小権限の原則**: Security Groupは必要最小限のポートのみ開放
2. **多層防御**: NACL + Security Group の2層で防御
3. **Private Subnet配置**: アプリケーション・データベースはすべてPrivate Subnet
4. **NAT Gateway経由**: インターネットへのEgressはNAT Gateway経由のみ
5. **VPC Flow Logs**: すべての通信をログ記録

### 基幹システム連携のセキュリティ

1. **VPN/Direct Connect**: 専用線で暗号化通信
2. **送信元IP制限**: 基幹システム側で送信元IPを制限
3. **相互認証**: VPN接続時の相互認証
4. **定期的な鍵更新**: VPN鍵の定期更新（年1回）

---

## ネットワーク拡張計画

### CIDR予約

| 用途 | CIDR | 状態 |
|------|------|------|
| 現在使用中 | 10.0.1.0/24, 10.0.2.0/24, 10.0.11.0/24, 10.0.12.0/24, 10.0.21.0/24, 10.0.22.0/24 | 使用中 |
| 将来の拡張用 | 10.0.3.0/24 ～ 10.0.10.0/24 | 予約済み |
| AZ追加用（ap-northeast-1d） | 10.0.3.0/24, 10.0.13.0/24, 10.0.23.0/24 | 予約済み |

### 将来的な拡張シナリオ

1. **3つ目のAZ追加**: 可用性向上のため、ap-northeast-1d を追加
2. **VPCピアリング**: 他の市町村との連携が必要な場合
3. **Transit Gateway**: 複数VPCを統合管理する場合

---

## まとめ

- **高可用性**: 2つのAZに冗長構成
- **セキュリティ**: 多層防御（NACL + Security Group）
- **拡張性**: CIDR予約により将来の拡張に対応
- **監視**: VPC Flow Logs で通信の可視化

---

**作成者**: architect
**レビュー状態**: Draft
**関連ドキュメント**: [network_design.md](network_design.md), [vpc_parameters.md](vpc_parameters.md)
