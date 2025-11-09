# ルートテーブル設定

## 文書管理情報

| 項目 | 内容 |
|------|------|
| 文書名 | ルートテーブル設定 |
| バージョン | 1.0 |
| 作成日 | 2025-11-05 |
| 最終更新日 | 2025-11-05 |
| ステータス | Draft |

---

## 1. 本番環境ルートテーブル

### 1.1 Public Route Table

```yaml
PublicRouteTable:
  VpcId: !Ref VPC
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-public-rt
    - Key: Type
      Value: Public
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.1.0.0/16 | local | VPC内部通信 |
| 0.0.0.0/0 | igw-xxxxx | インターネット向けトラフィック |
| 192.168.0.0/16 | tgw-xxxxx | 庁舎向けトラフィック（Direct Connect経由） |
| 10.2.0.0/16 | - | **ルートなし**（本番⇔ステージング通信禁止） |

**CloudFormationテンプレート**:
```yaml
InternetRoute:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PublicRouteTable
    DestinationCidrBlock: 0.0.0.0/0
    GatewayId: !Ref InternetGateway

TransitGatewayRoute:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PublicRouteTable
    DestinationCidrBlock: 192.168.0.0/16
    TransitGatewayId: !Ref TransitGateway
```

#### 関連付けサブネット

```yaml
PublicSubnet1aAssociation:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PublicSubnet1a
    RouteTableId: !Ref PublicRouteTable

PublicSubnet1cAssociation:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PublicSubnet1c
    RouteTableId: !Ref PublicRouteTable
```

---

### 1.2 Private App Route Table (AZ 1a)

```yaml
PrivateAppRouteTable1a:
  VpcId: !Ref VPC
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-app-rt-1a
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Application
    - Key: AZ
      Value: ap-northeast-1a
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.1.0.0/16 | local | VPC内部通信 |
| 0.0.0.0/0 | nat-1a | インターネット向けトラフィック（NAT Gateway経由） |
| 192.168.0.0/16 | tgw-xxxxx | 庁舎向けトラフィック |

**CloudFormationテンプレート**:
```yaml
InternetRouteApp1a:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PrivateAppRouteTable1a
    DestinationCidrBlock: 0.0.0.0/0
    NatGatewayId: !Ref NATGateway1a

TransitGatewayRouteApp1a:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PrivateAppRouteTable1a
    DestinationCidrBlock: 192.168.0.0/16
    TransitGatewayId: !Ref TransitGateway
```

#### 関連付けサブネット

```yaml
PrivateAppSubnet1aAssociation:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PrivateAppSubnet1a
    RouteTableId: !Ref PrivateAppRouteTable1a
```

---

### 1.3 Private App Route Table (AZ 1c)

```yaml
PrivateAppRouteTable1c:
  VpcId: !Ref VPC
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-app-rt-1c
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Application
    - Key: AZ
      Value: ap-northeast-1c
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.1.0.0/16 | local | VPC内部通信 |
| 0.0.0.0/0 | nat-1c | インターネット向けトラフィック（NAT Gateway経由） |
| 192.168.0.0/16 | tgw-xxxxx | 庁舎向けトラフィック |

**CloudFormationテンプレート**:
```yaml
InternetRouteApp1c:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PrivateAppRouteTable1c
    DestinationCidrBlock: 0.0.0.0/0
    NatGatewayId: !Ref NATGateway1c

TransitGatewayRouteApp1c:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PrivateAppRouteTable1c
    DestinationCidrBlock: 192.168.0.0/16
    TransitGatewayId: !Ref TransitGateway
```

#### 関連付けサブネット

```yaml
PrivateAppSubnet1cAssociation:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PrivateAppSubnet1c
    RouteTableId: !Ref PrivateAppRouteTable1c
```

---

### 1.4 Private DB Route Table

```yaml
PrivateDBRouteTable:
  VpcId: !Ref VPC
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-db-rt
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Database
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.1.0.0/16 | local | VPC内部通信 |
| 192.168.0.0/16 | tgw-xxxxx | 庁舎向けトラフィック（管理用） |

**注**: データベースサブネットはインターネットアクセス不要

**CloudFormationテンプレート**:
```yaml
TransitGatewayRouteDB:
  Type: AWS::EC2::Route
  Properties:
    RouteTableId: !Ref PrivateDBRouteTable
    DestinationCidrBlock: 192.168.0.0/16
    TransitGatewayId: !Ref TransitGateway
```

#### 関連付けサブネット

```yaml
PrivateDBSubnet1aAssociation:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PrivateDBSubnet1a
    RouteTableId: !Ref PrivateDBRouteTable

PrivateDBSubnet1cAssociation:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PrivateDBSubnet1c
    RouteTableId: !Ref PrivateDBRouteTable
```

---

### 1.5 Private Cache Route Table

```yaml
PrivateCacheRouteTable:
  VpcId: !Ref VPC
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-private-cache-rt
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Cache
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.1.0.0/16 | local | VPC内部通信のみ |

**注**: キャッシュサブネットは外部アクセス不要

**CloudFormationテンプレート**:
```yaml
# ルートはlocal（VPC内部）のみ、追加ルート不要
```

#### 関連付けサブネット

```yaml
PrivateCacheSubnet1aAssociation:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PrivateCacheSubnet1a
    RouteTableId: !Ref PrivateCacheRouteTable

PrivateCacheSubnet1cAssociation:
  Type: AWS::EC2::SubnetRouteTableAssociation
  Properties:
    SubnetId: !Ref PrivateCacheSubnet1c
    RouteTableId: !Ref PrivateCacheRouteTable
```

---

## 2. ステージング環境ルートテーブル

### 2.1 Public Route Table

```yaml
PublicRouteTableStg:
  VpcId: !Ref VPCStaging
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-public-rt
    - Key: Type
      Value: Public
    - Key: Environment
      Value: Staging
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.2.0.0/16 | local | VPC内部通信 |
| 0.0.0.0/0 | igw-xxxxx | インターネット向けトラフィック |
| 192.168.0.0/16 | tgw-xxxxx | 庁舎向けトラフィック |
| 10.1.0.0/16 | - | **ルートなし**（ステージング⇔本番通信禁止） |

---

### 2.2 Private App Route Table (AZ 1a)

```yaml
PrivateAppRouteTableStg1a:
  VpcId: !Ref VPCStaging
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-private-app-rt-1a
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Application
    - Key: AZ
      Value: ap-northeast-1a
    - Key: Environment
      Value: Staging
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.2.0.0/16 | local | VPC内部通信 |
| 0.0.0.0/0 | nat-stg-1a | インターネット向けトラフィック（NAT Gateway経由） |
| 192.168.0.0/16 | tgw-xxxxx | 庁舎向けトラフィック |

---

### 2.3 Private App Route Table (AZ 1c)

```yaml
PrivateAppRouteTableStg1c:
  VpcId: !Ref VPCStaging
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-private-app-rt-1c
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Application
    - Key: AZ
      Value: ap-northeast-1c
    - Key: Environment
      Value: Staging
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.2.0.0/16 | local | VPC内部通信 |
| 0.0.0.0/0 | nat-stg-1a | インターネット向けトラフィック（1aのNAT Gateway経由） |
| 192.168.0.0/16 | tgw-xxxxx | 庁舎向けトラフィック |

**注**: ステージング環境はコスト削減のため、NAT Gatewayは1aのみ。1cサブネットも1aのNAT Gatewayを使用。

---

### 2.4 Private DB Route Table

```yaml
PrivateDBRouteTableStg:
  VpcId: !Ref VPCStaging
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-private-db-rt
    - Key: Type
      Value: Private
    - Key: Layer
      Value: Database
    - Key: Environment
      Value: Staging
```

#### ルート設定

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.2.0.0/16 | local | VPC内部通信 |
| 192.168.0.0/16 | tgw-xxxxx | 庁舎向けトラフィック（管理用） |

---

## 3. ルートテーブル一覧（サマリー）

### 3.1 本番環境

| ルートテーブル名 | 関連サブネット | インターネット | Transit Gateway | 備考 |
|---------------|-------------|-------------|----------------|------|
| niigata-kaigo-prod-public-rt | Public 1a, 1c | IGW経由 | 有効 | NAT Gateway、ALB用 |
| niigata-kaigo-prod-private-app-rt-1a | Private App 1a | NAT 1a経由 | 有効 | ECS Fargate用 |
| niigata-kaigo-prod-private-app-rt-1c | Private App 1c | NAT 1c経由 | 有効 | ECS Fargate用 |
| niigata-kaigo-prod-private-db-rt | Private DB 1a, 1c | なし | 有効 | RDS MySQL用 |
| niigata-kaigo-prod-private-cache-rt | Private Cache 1a, 1c | なし | なし | ElastiCache用 |

### 3.2 ステージング環境

| ルートテーブル名 | 関連サブネット | インターネット | Transit Gateway | 備考 |
|---------------|-------------|-------------|----------------|------|
| niigata-kaigo-stg-public-rt | Public 1a, 1c | IGW経由 | 有効 | NAT Gateway、ALB用 |
| niigata-kaigo-stg-private-app-rt-1a | Private App 1a | NAT 1a経由 | 有効 | ECS Fargate用 |
| niigata-kaigo-stg-private-app-rt-1c | Private App 1c | NAT 1a経由 | 有効 | ECS Fargate用（1aのNAT使用） |
| niigata-kaigo-stg-private-db-rt | Private DB 1a, 1c | なし | 有効 | RDS MySQL用 |

---

## 4. ルーティングフロー図

### 4.1 本番環境アプリケーションからインターネットへのアクセス

```
ECS Fargate (10.1.11.x)
  ↓
Private App Subnet (10.1.11.0/24)
  ↓
Private App Route Table 1a (0.0.0.0/0 → NAT Gateway 1a)
  ↓
NAT Gateway (Public Subnet 1a)
  ↓
Public Route Table (0.0.0.0/0 → Internet Gateway)
  ↓
Internet Gateway
  ↓
インターネット
```

### 4.2 本番環境アプリケーションから庁舎へのアクセス

```
ECS Fargate (10.1.11.x)
  ↓
Private App Subnet (10.1.11.0/24)
  ↓
Private App Route Table 1a (192.168.0.0/16 → Transit Gateway)
  ↓
Transit Gateway
  ↓
Direct Connect Gateway
  ↓
Direct Connect (100Mbps × 2)
  ↓
新潟市庁舎 (192.168.0.0/16)
```

### 4.3 本番環境アプリケーションからRDSへのアクセス

```
ECS Fargate (10.1.11.x)
  ↓
Private App Subnet (10.1.11.0/24)
  ↓
VPC内部ルーティング (10.1.0.0/16 → local)
  ↓
Private DB Subnet (10.1.21.0/24)
  ↓
RDS MySQL (10.1.21.x)
```

---

## 5. セキュリティ考慮事項

### 5.1 環境間分離

- **本番⇔ステージング通信禁止**: Transit Gatewayのルートテーブルで制御
- ルートテーブルに 10.1.0.0/16 ⇔ 10.2.0.0/16 のルートを追加しない

### 5.2 データベース層の隔離

- データベースサブネットはインターネットアクセス不要
- NAT Gatewayへのルートを追加しない
- Transit Gatewayルートは管理用（庁舎からのメンテナンス）

### 5.3 キャッシュ層の完全隔離

- キャッシュサブネットはVPC内部通信のみ
- Transit Gateway、NAT Gatewayへのルートなし
- アプリケーション層からのみアクセス可能

---

## 6. CloudFormation実装方針

### 6.1 スタック分割

ルートテーブル関連リソースは以下のスタックに分割：

1. **route-tables-stack**: ルートテーブル作成
2. **routes-stack**: ルート追加（依存関係あり）
3. **subnet-associations-stack**: サブネット関連付け

### 6.2 パラメータ化

```yaml
Parameters:
  VPCId:
    Type: String
  InternetGatewayId:
    Type: String
  NATGateway1aId:
    Type: String
  NATGateway1cId:
    Type: String
  TransitGatewayId:
    Type: String
```

---

## 7. 参照

- [VPC詳細設計書](vpc_detailed_design.md)
- [サブネット割り当て表](subnet_allocation.md)
- [Transit Gateway詳細設計書](../02_transit_gateway_detailed/tgw_detailed_design.md)

---

**作成日**: 2025-11-05
**レビュー状態**: Draft
