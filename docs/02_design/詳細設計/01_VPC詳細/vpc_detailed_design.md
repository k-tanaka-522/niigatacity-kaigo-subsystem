# VPC詳細設計書

## 文書管理情報

| 項目 | 内容 |
|------|------|
| 文書名 | VPC詳細設計書 |
| バージョン | 1.0 |
| 作成日 | 2025-11-05 |
| 最終更新日 | 2025-11-05 |
| ステータス | Draft |

---

## 1. VPC設計概要

### 1.1 設計方針

- **Multi-AZ構成**: 高可用性を確保するため、すべてのリソースを2つのAvailability Zoneに配置
- **プライベートサブネット優先**: アプリケーション、データベース、キャッシュはインターネットから隔離
- **セグメント分離**: アプリケーション、データベース、キャッシュを別々のサブネットに配置
- **Transit Gateway統合**: アカウント間通信、Direct Connect接続をTransit Gateway経由で実現

---

## 2. 本番環境VPC

### 2.1 VPC基本設定

```yaml
VPC:
  Name: niigata-kaigo-prod-vpc
  CIDR: 10.1.0.0/16
  Region: ap-northeast-1
  EnableDnsSupport: true
  EnableDnsHostnames: true
  Tags:
    - Key: Environment
      Value: Production
    - Key: Project
      Value: niigata-kaigo
    - Key: ManagedBy
      Value: CloudFormation
```

### 2.2 Internet Gateway

```yaml
InternetGateway:
  Name: niigata-kaigo-prod-igw
  AttachedTo: niigata-kaigo-prod-vpc
  Tags:
    - Key: Environment
      Value: Production
    - Key: Project
      Value: niigata-kaigo
```

### 2.3 NAT Gateway

#### NAT Gateway 1a

```yaml
NATGateway1a:
  Name: niigata-kaigo-prod-nat-1a
  Subnet: niigata-kaigo-prod-public-subnet-1a
  AllocationId: !Ref EIP1a
  Tags:
    - Key: Environment
      Value: Production
    - Key: AZ
      Value: ap-northeast-1a
```

**Elastic IP for NAT Gateway 1a**:
```yaml
EIP1a:
  Domain: vpc
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-eip-nat-1a
```

#### NAT Gateway 1c

```yaml
NATGateway1c:
  Name: niigata-kaigo-prod-nat-1c
  Subnet: niigata-kaigo-prod-public-subnet-1c
  AllocationId: !Ref EIP1c
  Tags:
    - Key: Environment
      Value: Production
    - Key: AZ
      Value: ap-northeast-1c
```

**Elastic IP for NAT Gateway 1c**:
```yaml
EIP1c:
  Domain: vpc
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-eip-nat-1c
```

### 2.4 VPC Flow Logs

```yaml
VPCFlowLogs:
  ResourceType: VPC
  ResourceId: !Ref VPC
  TrafficType: ALL
  LogDestinationType: cloud-watch-logs
  LogGroupName: /aws/vpc/flowlogs/niigata-kaigo-prod-vpc
  DeliverLogsPermissionArn: !GetAtt VPCFlowLogsRole.Arn
  Tags:
    - Key: Environment
      Value: Production
```

**IAM Role for VPC Flow Logs**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowFlowLogsToCloudWatch",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 3. ステージング環境VPC

### 3.1 VPC基本設定

```yaml
VPC:
  Name: niigata-kaigo-stg-vpc
  CIDR: 10.2.0.0/16
  Region: ap-northeast-1
  EnableDnsSupport: true
  EnableDnsHostnames: true
  Tags:
    - Key: Environment
      Value: Staging
    - Key: Project
      Value: niigata-kaigo
    - Key: ManagedBy
      Value: CloudFormation
```

### 3.2 Internet Gateway

```yaml
InternetGateway:
  Name: niigata-kaigo-stg-igw
  AttachedTo: niigata-kaigo-stg-vpc
  Tags:
    - Key: Environment
      Value: Staging
    - Key: Project
      Value: niigata-kaigo
```

### 3.3 NAT Gateway

**注**: ステージング環境はコスト削減のため、NAT Gatewayは1AZのみ

```yaml
NATGateway1a:
  Name: niigata-kaigo-stg-nat-1a
  Subnet: niigata-kaigo-stg-public-subnet-1a
  AllocationId: !Ref EIPStg1a
  Tags:
    - Key: Environment
      Value: Staging
    - Key: AZ
      Value: ap-northeast-1a
```

**Elastic IP for NAT Gateway 1a**:
```yaml
EIPStg1a:
  Domain: vpc
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-eip-nat-1a
```

### 3.4 VPC Flow Logs

```yaml
VPCFlowLogs:
  ResourceType: VPC
  ResourceId: !Ref VPCStaging
  TrafficType: ALL
  LogDestinationType: cloud-watch-logs
  LogGroupName: /aws/vpc/flowlogs/niigata-kaigo-stg-vpc
  DeliverLogsPermissionArn: !GetAtt VPCFlowLogsRole.Arn
  LogRetentionInDays: 30
  Tags:
    - Key: Environment
      Value: Staging
```

---

## 4. Transit Gateway Attachment

### 4.1 本番環境Attachment

```yaml
TransitGatewayAttachment:
  TransitGatewayId: !Ref TransitGateway
  VpcId: !Ref VPCProduction
  SubnetIds:
    - !Ref PrivateAppSubnet1a
    - !Ref PrivateAppSubnet1c
  Tags:
    - Key: Name
      Value: niigata-kaigo-prod-tgw-attachment
    - Key: Environment
      Value: Production
```

### 4.2 ステージング環境Attachment

```yaml
TransitGatewayAttachment:
  TransitGatewayId: !Ref TransitGateway
  VpcId: !Ref VPCStaging
  SubnetIds:
    - !Ref PrivateAppSubnetStg1a
    - !Ref PrivateAppSubnetStg1c
  Tags:
    - Key: Name
      Value: niigata-kaigo-stg-tgw-attachment
    - Key: Environment
      Value: Staging
```

---

## 5. Security Groups

### 5.1 VPC Endpoints Security Group

```yaml
VPCEndpointsSecurityGroup:
  GroupName: niigata-kaigo-vpce-sg
  GroupDescription: Security group for VPC Endpoints (S3, ECR, Secrets Manager)
  VpcId: !Ref VPC
  SecurityGroupIngress:
    - IpProtocol: tcp
      FromPort: 443
      ToPort: 443
      SourceSecurityGroupId: !Ref ECSSecurityGroup
      Description: Allow HTTPS from ECS
  SecurityGroupEgress:
    - IpProtocol: -1
      CidrIp: 0.0.0.0/0
  Tags:
    - Key: Name
      Value: niigata-kaigo-vpce-sg
```

---

## 6. VPC Endpoints

### 6.1 S3 Gateway Endpoint

```yaml
S3Endpoint:
  ServiceName: !Sub 'com.amazonaws.${AWS::Region}.s3'
  VpcId: !Ref VPC
  RouteTableIds:
    - !Ref PrivateAppRouteTable1a
    - !Ref PrivateAppRouteTable1c
  PolicyDocument:
    Version: '2012-10-17'
    Statement:
      - Effect: Allow
        Principal: '*'
        Action:
          - 's3:GetObject'
          - 's3:PutObject'
          - 's3:ListBucket'
        Resource:
          - !Sub 'arn:aws:s3:::niigata-kaigo-prod-*'
          - !Sub 'arn:aws:s3:::niigata-kaigo-prod-*/*'
```

### 6.2 Interface Endpoints

#### ECR API Endpoint

```yaml
ECRApiEndpoint:
  ServiceName: !Sub 'com.amazonaws.${AWS::Region}.ecr.api'
  VpcId: !Ref VPC
  SubnetIds:
    - !Ref PrivateAppSubnet1a
    - !Ref PrivateAppSubnet1c
  SecurityGroupIds:
    - !Ref VPCEndpointsSecurityGroup
  PrivateDnsEnabled: true
  VpcEndpointType: Interface
```

#### ECR DKR Endpoint

```yaml
ECRDkrEndpoint:
  ServiceName: !Sub 'com.amazonaws.${AWS::Region}.ecr.dkr'
  VpcId: !Ref VPC
  SubnetIds:
    - !Ref PrivateAppSubnet1a
    - !Ref PrivateAppSubnet1c
  SecurityGroupIds:
    - !Ref VPCEndpointsSecurityGroup
  PrivateDnsEnabled: true
  VpcEndpointType: Interface
```

#### Secrets Manager Endpoint

```yaml
SecretsManagerEndpoint:
  ServiceName: !Sub 'com.amazonaws.${AWS::Region}.secretsmanager'
  VpcId: !Ref VPC
  SubnetIds:
    - !Ref PrivateAppSubnet1a
    - !Ref PrivateAppSubnet1c
  SecurityGroupIds:
    - !Ref VPCEndpointsSecurityGroup
  PrivateDnsEnabled: true
  VpcEndpointType: Interface
```

#### CloudWatch Logs Endpoint

```yaml
CloudWatchLogsEndpoint:
  ServiceName: !Sub 'com.amazonaws.${AWS::Region}.logs'
  VpcId: !Ref VPC
  SubnetIds:
    - !Ref PrivateAppSubnet1a
    - !Ref PrivateAppSubnet1c
  SecurityGroupIds:
    - !Ref VPCEndpointsSecurityGroup
  PrivateDnsEnabled: true
  VpcEndpointType: Interface
```

---

## 7. DHCP Options Set

```yaml
DHCPOptions:
  DomainName: !Sub '${AWS::Region}.compute.internal'
  DomainNameServers:
    - AmazonProvidedDNS
  Tags:
    - Key: Name
      Value: niigata-kaigo-dhcp-options
```

---

## 8. 設定値一覧

### 8.1 本番環境

| 項目 | 値 |
|------|-----|
| VPC CIDR | 10.1.0.0/16 |
| Internet Gateway | niigata-kaigo-prod-igw |
| NAT Gateway (1a) | niigata-kaigo-prod-nat-1a |
| NAT Gateway (1c) | niigata-kaigo-prod-nat-1c |
| VPC Flow Logs保持期間 | 90日 |

### 8.2 ステージング環境

| 項目 | 値 |
|------|-----|
| VPC CIDR | 10.2.0.0/16 |
| Internet Gateway | niigata-kaigo-stg-igw |
| NAT Gateway (1a) | niigata-kaigo-stg-nat-1a |
| NAT Gateway (1c) | なし（コスト削減） |
| VPC Flow Logs保持期間 | 30日 |

---

## 9. CloudFormation実装方針

### 9.1 スタック分割

VPC関連リソースは以下のスタックに分割します：

1. **vpc-core-stack**: VPC、Internet Gateway、DHCP Options
2. **vpc-nat-stack**: NAT Gateway、Elastic IP
3. **vpc-endpoints-stack**: VPC Endpoints
4. **vpc-flowlogs-stack**: VPC Flow Logs

### 9.2 スタック依存関係

```
vpc-core-stack
  ↓
vpc-nat-stack
  ↓
vpc-endpoints-stack
  ↓
vpc-flowlogs-stack
```

---

## 10. 参照

- [サブネット割り当て表](subnet_allocation.md)
- [ルートテーブル設定](route_table_config.md)
- [基本設計書 - ネットワーク設計](../../basic/03_network/network_design.md)

---

**作成日**: 2025-11-05
**レビュー状態**: Draft
