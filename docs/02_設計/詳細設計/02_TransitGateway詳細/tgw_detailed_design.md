# Transit Gateway詳細設計書

## 文書管理情報

| 項目 | 内容 |
|------|------|
| 文書名 | Transit Gateway詳細設計書 |
| バージョン | 1.0 |
| 作成日 | 2025-11-05 |
| 最終更新日 | 2025-11-05 |
| ステータス | Draft |

---

## 1. Transit Gateway概要

### 1.1 設計方針

- **ハブ&スポークモデル**: Transit Gatewayをハブとして、本番・ステージングVPC、Direct Connectを接続
- **環境間分離**: 本番⇔ステージング間の通信を禁止
- **カスタムルートテーブル**: デフォルトルートテーブルを使用せず、カスタムルートテーブルで制御
- **BGP動的ルーティング**: Direct Connect経由で庁舎とBGPピアリング

---

## 2. Transit Gateway基本設定

### 2.1 Transit Gateway

```yaml
TransitGateway:
  Description: Transit Gateway for Niigata Kaigo System
  AmazonSideAsn: 64512
  DefaultRouteTableAssociation: disable
  DefaultRouteTablePropagation: disable
  DnsSupport: enable
  VpnEcmpSupport: enable
  Tags:
    - Key: Name
      Value: niigata-kaigo-tgw
    - Key: Project
      Value: niigata-kaigo
    - Key: ManagedBy
      Value: CloudFormation
```

**主要パラメータ**:
| パラメータ | 値 | 説明 |
|----------|-----|------|
| AmazonSideAsn | 64512 | AWS側のBGP ASN |
| DefaultRouteTableAssociation | disable | カスタムルートテーブル使用 |
| DefaultRouteTablePropagation | disable | 自動ルート伝播無効 |
| DnsSupport | enable | Route 53 Resolver有効 |
| VpnEcmpSupport | enable | ECMP（Equal Cost Multi-Path）有効 |

---

## 3. Transit Gateway Attachments

### 3.1 本番アプリ系VPC Attachment

```yaml
ProdVPCAttachment:
  TransitGatewayId: !Ref TransitGateway
  VpcId: !ImportValue niigata-kaigo-prod-vpc-id
  SubnetIds:
    - !ImportValue niigata-kaigo-prod-private-app-subnet-1a-id
    - !ImportValue niigata-kaigo-prod-private-app-subnet-1c-id
  DnsSupport: enable
  Ipv6Support: disable
  ApplianceModeSupport: disable
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-vpc-attachment
    - Key: Environment
      Value: Production
```

### 3.2 ステージングアプリ系VPC Attachment

```yaml
StgVPCAttachment:
  TransitGatewayId: !Ref TransitGateway
  VpcId: !ImportValue niigata-kaigo-stg-vpc-id
  SubnetIds:
    - !ImportValue niigata-kaigo-stg-private-app-subnet-1a-id
    - !ImportValue niigata-kaigo-stg-private-app-subnet-1c-id
  DnsSupport: enable
  Ipv6Support: disable
  ApplianceModeSupport: disable
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-vpc-attachment
    - Key: Environment
      Value: Staging
```

### 3.3 Direct Connect Gateway Attachment

```yaml
DirectConnectGatewayAssociation:
  TransitGatewayId: !Ref TransitGateway
  DirectConnectGatewayId: !Ref DirectConnectGateway
  AllowedPrefixes:
    - 192.168.0.0/16  # 庁舎側ネットワーク
  Tags:
    - Key: Name
      Value: niigata-kaigo-dx-gateway-attachment
```

---

## 4. Transit Gateway Route Tables

### 4.1 本番環境用ルートテーブル

```yaml
ProdTGWRouteTable:
  TransitGatewayId: !Ref TransitGateway
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-tgw-rt
    - Key: Environment
      Value: Production
```

**Association**:
```yaml
ProdVPCAssociation:
  TransitGatewayAttachmentId: !Ref ProdVPCAttachment
  TransitGatewayRouteTableId: !Ref ProdTGWRouteTable
```

**Routes**:
```yaml
ProdToDXRoute:
  TransitGatewayRouteTableId: !Ref ProdTGWRouteTable
  DestinationCidrBlock: 192.168.0.0/16
  TransitGatewayAttachmentId: !Ref DirectConnectGatewayAssociation
```

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 192.168.0.0/16 | Direct Connect Gateway | 庁舎向けトラフィック |
| 10.2.0.0/16 | - | **ルートなし**（本番⇔ステージング通信禁止） |

---

### 4.2 ステージング環境用ルートテーブル

```yaml
StgTGWRouteTable:
  TransitGatewayId: !Ref TransitGateway
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-tgw-rt
    - Key: Environment
      Value: Staging
```

**Association**:
```yaml
StgVPCAssociation:
  TransitGatewayAttachmentId: !Ref StgVPCAttachment
  TransitGatewayRouteTableId: !Ref StgTGWRouteTable
```

**Routes**:
```yaml
StgToDXRoute:
  TransitGatewayRouteTableId: !Ref StgTGWRouteTable
  DestinationCidrBlock: 192.168.0.0/16
  TransitGatewayAttachmentId: !Ref DirectConnectGatewayAssociation
```

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 192.168.0.0/16 | Direct Connect Gateway | 庁舎向けトラフィック |
| 10.1.0.0/16 | - | **ルートなし**（ステージング⇔本番通信禁止） |

---

### 4.3 Direct Connect用ルートテーブル

```yaml
DXTGWRouteTable:
  TransitGatewayId: !Ref TransitGateway
  Tags:
    - Key: Name
      Value: niigata-kaigo-dx-tgw-rt
```

**Association**:
```yaml
DXAssociation:
  TransitGatewayAttachmentId: !Ref DirectConnectGatewayAssociation
  TransitGatewayRouteTableId: !Ref DXTGWRouteTable
```

**Routes**:
```yaml
DXToProdRoute:
  TransitGatewayRouteTableId: !Ref DXTGWRouteTable
  DestinationCidrBlock: 10.1.0.0/16
  TransitGatewayAttachmentId: !Ref ProdVPCAttachment

DXToStgRoute:
  TransitGatewayRouteTableId: !Ref DXTGWRouteTable
  DestinationCidrBlock: 10.2.0.0/16
  TransitGatewayAttachmentId: !Ref StgVPCAttachment
```

| 宛先 | ターゲット | 説明 |
|------|----------|------|
| 10.1.0.0/16 | 本番VPC Attachment | 本番環境向けトラフィック |
| 10.2.0.0/16 | ステージングVPC Attachment | ステージング環境向けトラフィック |

---

## 5. BGP設定

### 5.1 BGP Parameters

| 項目 | AWS側 | 庁舎側 |
|------|------|--------|
| ASN | 64512 | 65000 |
| BGP認証 | MD5認証 | MD5認証 |
| キープアライブ | 30秒 | 30秒 |
| ホールドタイム | 90秒 | 90秒 |

### 5.2 BGP Peer設定（回線1）

```yaml
BGPPeer1:
  PeerIP: 169.254.100.2
  AmazonIP: 169.254.100.1
  ASN: 65000
  VLANId: 101
  AddressFamily: ipv4
  AuthKey: !Ref BGPAuthKeySecret1
```

### 5.3 BGP Peer設定（回線2）

```yaml
BGPPeer2:
  PeerIP: 169.254.100.6
  AmazonIP: 169.254.100.5
  ASN: 65000
  VLANId: 102
  AddressFamily: ipv4
  AuthKey: !Ref BGPAuthKeySecret2
```

---

## 6. Direct Connect Gateway

### 6.1 Direct Connect Gateway設定

```yaml
DirectConnectGateway:
  Name: niigata-kaigo-dxgw
  AmazonSideAsn: 64512
  Tags:
    - Key: Name
      Value: niigata-kaigo-dxgw
    - Key: Project
      Value: niigata-kaigo
```

### 6.2 Direct Connect Gateway - Transit Gateway Association

```yaml
DXGWTGWAssociation:
  DirectConnectGatewayId: !Ref DirectConnectGateway
  TransitGatewayId: !Ref TransitGateway
  AllowedPrefixes:
    - 10.1.0.0/16  # 本番VPC
    - 10.2.0.0/16  # ステージングVPC
```

---

## 7. Direct Connect接続

### 7.1 回線1（Primary）

```yaml
DirectConnectConnection1:
  ConnectionName: niigata-kaigo-dx-primary
  Bandwidth: 100Mbps
  Location: Equinix Tokyo (TY2)
  ProviderName: [プロバイダー名]
  Tags:
    - Key: Name
      Value: niigata-kaigo-dx-primary
    - Key: Type
      Value: Primary
```

### 7.2 回線2（Secondary）

```yaml
DirectConnectConnection2:
  ConnectionName: niigata-kaigo-dx-secondary
  Bandwidth: 100Mbps
  Location: Equinix Tokyo (TY2)
  ProviderName: [プロバイダー名]
  Tags:
    - Key: Name
      Value: niigata-kaigo-dx-secondary
    - Key: Type
      Value: Secondary
```

---

## 8. Virtual Interface設定

### 8.1 Private VIF 1（Primary）

```yaml
PrivateVIF1:
  ConnectionId: !Ref DirectConnectConnection1
  VirtualInterfaceName: niigata-kaigo-private-vif-primary
  VirtualInterfaceType: private
  Vlan: 101
  Asn: 65000
  Mtu: 1500
  AddressFamily: ipv4
  AmazonAddress: 169.254.100.1/30
  CustomerAddress: 169.254.100.2/30
  DirectConnectGatewayId: !Ref DirectConnectGateway
  Tags:
    - Key: Name
      Value: niigata-kaigo-private-vif-primary
```

### 8.2 Private VIF 2（Secondary）

```yaml
PrivateVIF2:
  ConnectionId: !Ref DirectConnectConnection2
  VirtualInterfaceName: niigata-kaigo-private-vif-secondary
  VirtualInterfaceType: private
  Vlan: 102
  Asn: 65000
  Mtu: 1500
  AddressFamily: ipv4
  AmazonAddress: 169.254.100.5/30
  CustomerAddress: 169.254.100.6/30
  DirectConnectGatewayId: !Ref DirectConnectGateway
  Tags:
    - Key: Name
      Value: niigata-kaigo-private-vif-secondary
```

---

## 9. 冗長性設計

### 9.1 冗長構成

- **2回線構成**: Primary/Secondaryの2つのDirect Connect接続
- **BGP ECMP**: 2回線で負荷分散
- **自動フェイルオーバー**: BGPセッション断で自動切り替え
- **フェイルオーバー時間**: 約60-90秒（BGPホールドタイム）

### 9.2 障害シナリオ

| 障害 | 影響 | 復旧方法 |
|------|------|---------|
| 回線1障害 | 回線2に自動切り替え | BGP自動フェイルオーバー |
| 回線2障害 | 回線1に自動切り替え | BGP自動フェイルオーバー |
| 両回線障害 | 庁舎からのアクセス不可 | 回線復旧待ち |
| Transit Gateway障害 | 全環境影響 | AWSサポート対応 |

---

## 10. 監視設計

### 10.1 CloudWatch Metrics

```yaml
TransitGatewayMetrics:
  - BytesIn
  - BytesOut
  - PacketsIn
  - PacketsOut
  - PacketDropCountBlackhole
  - PacketDropCountNoRoute

DirectConnectMetrics:
  - ConnectionState
  - ConnectionBpsEgress
  - ConnectionBpsIngress
  - ConnectionPpsEgress
  - ConnectionPpsIngress
  - ConnectionLightLevelTx
  - ConnectionLightLevelRx
```

### 10.2 アラーム設定

```yaml
DXConnectionStateAlarm:
  MetricName: ConnectionState
  Namespace: AWS/DX
  Statistic: Maximum
  Period: 60
  EvaluationPeriods: 2
  Threshold: 1
  ComparisonOperator: LessThanThreshold
  AlarmActions:
    - !Ref SNSTopicCritical

TGWPacketDropAlarm:
  MetricName: PacketDropCountNoRoute
  Namespace: AWS/TransitGateway
  Statistic: Sum
  Period: 300
  EvaluationPeriods: 1
  Threshold: 100
  ComparisonOperator: GreaterThanThreshold
  AlarmActions:
    - !Ref SNSTopicWarning
```

---

## 11. CloudFormation実装方針

### 11.1 スタック分割

1. **tgw-core-stack**: Transit Gateway本体
2. **tgw-attachments-stack**: VPC Attachments
3. **tgw-route-tables-stack**: Route Tables
4. **dx-gateway-stack**: Direct Connect Gateway
5. **dx-connections-stack**: Direct Connect接続、Virtual Interface

### 11.2 スタック依存関係

```
tgw-core-stack
  ↓
tgw-attachments-stack
  ↓
tgw-route-tables-stack
  ↓
dx-gateway-stack
  ↓
dx-connections-stack
```

---

## 12. セキュリティ考慮事項

### 12.1 環境間分離

- 本番⇔ステージング間のルートを作成しない
- Transit Gatewayルートテーブルで制御
- VPC Security Groupで多層防御

### 12.2 BGP認証

- MD5認証必須
- パスワードはAWS Secrets Managerで管理
- 定期的なパスワードローテーション（年1回）

---

## 13. 参照

- [Transit Gatewayルートテーブル設定](tgw_route_tables.md)
- [Direct Connect詳細設計](../03_direct_connect_detailed/dx_detailed_design.md)
- [基本設計書 - ネットワーク設計](../../basic/03_network/network_design.md)

---

**作成日**: 2025-11-05
**レビュー状態**: Draft
