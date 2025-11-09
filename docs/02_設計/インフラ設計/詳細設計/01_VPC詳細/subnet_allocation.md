# サブネット割り当て表

## 文書管理情報

| 項目 | 内容 |
|------|------|
| 文書名 | サブネット割り当て表 |
| バージョン | 1.0 |
| 作成日 | 2025-11-05 |
| 最終更新日 | 2025-11-05 |
| ステータス | Draft |

---

## 1. 本番環境サブネット割り当て

### 1.1 全体構成

| レイヤー | CIDR範囲 | 用途 |
|---------|---------|------|
| Public | 10.1.1.0/24 - 10.1.9.0/24 | インターネットゲートウェイ経由のアクセス |
| Private App | 10.1.11.0/24 - 10.1.19.0/24 | アプリケーション層 |
| Private DB | 10.1.21.0/24 - 10.1.29.0/24 | データベース層 |
| Private Cache | 10.1.31.0/24 - 10.1.39.0/24 | キャッシュ層 |

---

### 1.2 Public Subnet

#### Public Subnet 1a

```yaml
PublicSubnet1a:
  CidrBlock: 10.1.1.0/24
  AvailabilityZone: ap-northeast-1a
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-public-subnet-1a
    - Key: Type
      Value: Public
    - Key: AZ
      Value: ap-northeast-1a
```

**IP範囲**:
- 開始IP: 10.1.1.0
- 終了IP: 10.1.1.255
- 使用可能IP数: 251（AWSが5つ予約）
- 用途: NAT Gateway、ALB

**予約済みIP**:
- 10.1.1.0: ネットワークアドレス
- 10.1.1.1: VPCルーター
- 10.1.1.2: DNSサーバー
- 10.1.1.3: 将来の使用のためAWSが予約
- 10.1.1.255: ブロードキャストアドレス

#### Public Subnet 1c

```yaml
PublicSubnet1c:
  CidrBlock: 10.1.2.0/24
  AvailabilityZone: ap-northeast-1c
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-public-subnet-1c
    - Key: Type
      Value: Public
    - Key: AZ
      Value: ap-northeast-1c
```

**IP範囲**:
- 開始IP: 10.1.2.0
- 終了IP: 10.1.2.255
- 使用可能IP数: 251
- 用途: NAT Gateway、ALB

---

### 1.3 Private App Subnet

#### Private App Subnet 1a

```yaml
PrivateAppSubnet1a:
  CidrBlock: 10.1.11.0/24
  AvailabilityZone: ap-northeast-1a
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-app-subnet-1a
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Application
    - Key: AZ
      Value: ap-northeast-1a
```

**IP範囲**:
- 開始IP: 10.1.11.0
- 終了IP: 10.1.11.255
- 使用可能IP数: 251
- 用途: ECS Fargate タスク

**想定リソース配置**:
- ECS Fargate タスク: 最大50タスク（1タスク = 1 ENI）
- VPC Endpoints ENI: 10個程度
- 予備: 190個程度

#### Private App Subnet 1c

```yaml
PrivateAppSubnet1c:
  CidrBlock: 10.1.12.0/24
  AvailabilityZone: ap-northeast-1c
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-app-subnet-1c
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Application
    - Key: AZ
      Value: ap-northeast-1c
```

**IP範囲**:
- 開始IP: 10.1.12.0
- 終了IP: 10.1.12.255
- 使用可能IP数: 251
- 用途: ECS Fargate タスク

---

### 1.4 Private DB Subnet

#### Private DB Subnet 1a

```yaml
PrivateDBSubnet1a:
  CidrBlock: 10.1.21.0/24
  AvailabilityZone: ap-northeast-1a
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-db-subnet-1a
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Database
    - Key: AZ
      Value: ap-northeast-1a
```

**IP範囲**:
- 開始IP: 10.1.21.0
- 終了IP: 10.1.21.255
- 使用可能IP数: 251
- 用途: RDS MySQL (Primary)

**想定リソース配置**:
- RDS MySQL Primary: 1個（ENI 1個）
- 予備: 250個

#### Private DB Subnet 1c

```yaml
PrivateDBSubnet1c:
  CidrBlock: 10.1.22.0/24
  AvailabilityZone: ap-northeast-1c
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-db-subnet-1c
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Database
    - Key: AZ
      Value: ap-northeast-1c
```

**IP範囲**:
- 開始IP: 10.1.22.0
- 終了IP: 10.1.22.255
- 使用可能IP数: 251
- 用途: RDS MySQL (Standby for Multi-AZ)

---

### 1.5 Private Cache Subnet

#### Private Cache Subnet 1a

```yaml
PrivateCacheSubnet1a:
  CidrBlock: 10.1.31.0/24
  AvailabilityZone: ap-northeast-1a
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-cache-subnet-1a
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Cache
    - Key: AZ
      Value: ap-northeast-1a
```

**IP範囲**:
- 開始IP: 10.1.31.0
- 終了IP: 10.1.31.255
- 使用可能IP数: 251
- 用途: ElastiCache Redis (Primary)

**想定リソース配置**:
- ElastiCache Redis Primary: 1個（ENI 1個）
- 予備: 250個

#### Private Cache Subnet 1c

```yaml
PrivateCacheSubnet1c:
  CidrBlock: 10.1.32.0/24
  AvailabilityZone: ap-northeast-1c
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-cache-subnet-1c
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Cache
    - Key: AZ
      Value: ap-northeast-1c
```

**IP範囲**:
- 開始IP: 10.1.32.0
- 終了IP: 10.1.32.255
- 使用可能IP数: 251
- 用途: ElastiCache Redis (Replica)

---

## 2. ステージング環境サブネット割り当て

### 2.1 全体構成

| レイヤー | CIDR範囲 | 用途 |
|---------|---------|------|
| Public | 10.2.1.0/24 - 10.2.9.0/24 | インターネットゲートウェイ経由のアクセス |
| Private App | 10.2.11.0/24 - 10.2.19.0/24 | アプリケーション層 |
| Private DB | 10.2.21.0/24 - 10.2.29.0/24 | データベース層 |

**注**: ステージング環境ではキャッシュサブネットは省略（コスト削減）

---

### 2.2 Public Subnet

#### Public Subnet 1a

```yaml
PublicSubnetStg1a:
  CidrBlock: 10.2.1.0/24
  AvailabilityZone: ap-northeast-1a
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-public-subnet-1a
    - Key: Type
      Value: Public
    - Key: AZ
      Value: ap-northeast-1a
    - Key: Environment
      Value: Staging
```

**IP範囲**:
- 開始IP: 10.2.1.0
- 終了IP: 10.2.1.255
- 使用可能IP数: 251
- 用途: NAT Gateway、ALB

#### Public Subnet 1c

```yaml
PublicSubnetStg1c:
  CidrBlock: 10.2.2.0/24
  AvailabilityZone: ap-northeast-1c
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-public-subnet-1c
    - Key: Type
      Value: Public
    - Key: AZ
      Value: ap-northeast-1c
    - Key: Environment
      Value: Staging
```

**IP範囲**:
- 開始IP: 10.2.2.0
- 終了IP: 10.2.2.255
- 使用可能IP数: 251
- 用途: ALB（NAT Gatewayは1aのみ）

---

### 2.3 Private App Subnet

#### Private App Subnet 1a

```yaml
PrivateAppSubnetStg1a:
  CidrBlock: 10.2.11.0/24
  AvailabilityZone: ap-northeast-1a
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-private-app-subnet-1a
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Application
    - Key: AZ
      Value: ap-northeast-1a
    - Key: Environment
      Value: Staging
```

**IP範囲**:
- 開始IP: 10.2.11.0
- 終了IP: 10.2.11.255
- 使用可能IP数: 251
- 用途: ECS Fargate タスク

#### Private App Subnet 1c

```yaml
PrivateAppSubnetStg1c:
  CidrBlock: 10.2.12.0/24
  AvailabilityZone: ap-northeast-1c
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-private-app-subnet-1c
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Application
    - Key: AZ
      Value: ap-northeast-1c
    - Key: Environment
      Value: Staging
```

**IP範囲**:
- 開始IP: 10.2.12.0
- 終了IP: 10.2.12.255
- 使用可能IP数: 251
- 用途: ECS Fargate タスク

---

### 2.4 Private DB Subnet

#### Private DB Subnet 1a

```yaml
PrivateDBSubnetStg1a:
  CidrBlock: 10.2.21.0/24
  AvailabilityZone: ap-northeast-1a
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-private-db-subnet-1a
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Database
    - Key: AZ
      Value: ap-northeast-1a
    - Key: Environment
      Value: Staging
```

**IP範囲**:
- 開始IP: 10.2.21.0
- 終了IP: 10.2.21.255
- 使用可能IP数: 251
- 用途: RDS MySQL (Single-AZ)

#### Private DB Subnet 1c

```yaml
PrivateDBSubnetStg1c:
  CidrBlock: 10.2.22.0/24
  AvailabilityZone: ap-northeast-1c
  MapPublicIpOnLaunch: false
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-private-db-subnet-1c
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Database
    - Key: AZ
      Value: ap-northeast-1c
    - Key: Environment
      Value: Staging
```

**IP範囲**:
- 開始IP: 10.2.22.0
- 終了IP: 10.2.22.255
- 使用可能IP数: 251
- 用途: RDS Multi-AZ構成用のサブネット（必須、RDSがMulti-AZ用に自動使用）

---

## 3. サブネット割り当てサマリー

### 3.1 本番環境

| サブネット名 | CIDR | AZ | 用途 | 使用可能IP数 |
|------------|------|-----|------|-------------|
| niigata-kaigo-prod-public-subnet-1a | 10.1.1.0/24 | 1a | NAT Gateway、ALB | 251 |
| niigata-kaigo-prod-public-subnet-1c | 10.1.2.0/24 | 1c | NAT Gateway、ALB | 251 |
| niigata-kaigo-prod-private-app-subnet-1a | 10.1.11.0/24 | 1a | ECS Fargate | 251 |
| niigata-kaigo-prod-private-app-subnet-1c | 10.1.12.0/24 | 1c | ECS Fargate | 251 |
| niigata-kaigo-prod-private-db-subnet-1a | 10.1.21.0/24 | 1a | RDS Primary | 251 |
| niigata-kaigo-prod-private-db-subnet-1c | 10.1.22.0/24 | 1c | RDS Standby | 251 |
| niigata-kaigo-prod-private-cache-subnet-1a | 10.1.31.0/24 | 1a | ElastiCache Primary | 251 |
| niigata-kaigo-prod-private-cache-subnet-1c | 10.1.32.0/24 | 1c | ElastiCache Replica | 251 |

**合計**: 8サブネット、2,008 IP

### 3.2 ステージング環境

| サブネット名 | CIDR | AZ | 用途 | 使用可能IP数 |
|------------|------|-----|------|-------------|
| niigata-kaigo-stg-public-subnet-1a | 10.2.1.0/24 | 1a | NAT Gateway、ALB | 251 |
| niigata-kaigo-stg-public-subnet-1c | 10.2.2.0/24 | 1c | ALB | 251 |
| niigata-kaigo-stg-private-app-subnet-1a | 10.2.11.0/24 | 1a | ECS Fargate | 251 |
| niigata-kaigo-stg-private-app-subnet-1c | 10.2.12.0/24 | 1c | ECS Fargate | 251 |
| niigata-kaigo-stg-private-db-subnet-1a | 10.2.21.0/24 | 1a | RDS | 251 |
| niigata-kaigo-stg-private-db-subnet-1c | 10.2.22.0/24 | 1c | RDS (Multi-AZ用) | 251 |

**合計**: 6サブネット、1,506 IP

---

## 4. IP使用量見積もり

### 4.1 本番環境

| リソース | 数量 | IP使用数 |
|---------|------|---------|
| NAT Gateway | 2 | 2 |
| ALB | 2 (AZ × 2) | 4 |
| ECS Fargate タスク | 最大50 | 50 |
| RDS MySQL | 2 (Primary + Standby) | 2 |
| ElastiCache Redis | 2 (Primary + Replica) | 2 |
| VPC Endpoints ENI | 10 | 20 (2 AZ × 10) |
| **合計** | - | **80** |

**使用率**: 80 / 2,008 = 約4%

### 4.2 ステージング環境

| リソース | 数量 | IP使用数 |
|---------|------|---------|
| NAT Gateway | 1 | 1 |
| ALB | 2 (AZ × 2) | 4 |
| ECS Fargate タスク | 最大10 | 10 |
| RDS MySQL | 1 (Single-AZ) | 1 |
| VPC Endpoints ENI | 5 | 10 (2 AZ × 5) |
| **合計** | - | **26** |

**使用率**: 26 / 1,506 = 約2%

---

## 5. 拡張計画

### 5.1 将来的な拡張

現在のサブネット設計では、以下の拡張が可能です：

| 拡張項目 | 現在 | 拡張後 |
|---------|------|--------|
| ECS Fargate タスク数（本番） | 50 | 150（サブネット追加で対応） |
| ECS Fargate タスク数（ステージング） | 10 | 50 |
| RDS Read Replica追加 | 0 | 5 |

### 5.2 サブネット追加計画

将来的に以下のサブネットを追加する可能性があります：

- **10.1.13.0/24**: Private App Subnet 1d（第3AZ）
- **10.1.41.0/24 - 10.1.49.0/24**: Lambda専用サブネット（将来対応）

---

## 6. 参照

- [VPC詳細設計書](vpc_detailed_design.md)
- [ルートテーブル設定](route_table_config.md)
- [基本設計書 - ネットワーク設計](../../basic/03_network/network_design.md)

---

**作成日**: 2025-11-05
**レビュー状態**: Draft
