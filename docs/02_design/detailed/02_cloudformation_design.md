# CloudFormation IaC設計書 - 新潟市介護保険事業所システム

## ドキュメント管理情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | CloudFormation IaC設計書 |
| バージョン | 1.0.0 |
| 作成日 | 2025-11-05 |
| 最終更新日 | 2025-11-05 |
| ステータス | Draft |
| 前提ドキュメント | [AWS詳細設計書](01_aws_detailed_design.md) |

---

## 目次

1. [CloudFormation構成概要](#1-cloudformation構成概要)
2. [ディレクトリ構造](#2-ディレクトリ構造)
3. [スタック管理戦略](#3-スタック管理戦略)
4. [テンプレート設計](#4-テンプレート設計)
5. [パラメータ管理](#5-パラメータ管理)
6. [Change Set運用](#6-change-set運用)
7. [CI/CD統合](#7-cicd統合)
8. [セキュリティベストプラクティス](#8-セキュリティベストプラクティス)

---

## 1. CloudFormation構成概要

### 1.1 採用理由

| 項目 | 理由 |
|-----|------|
| AWSネイティブ | AWS公式のIaCツール、追加インストール不要 |
| Change Setによる安全な変更 | 変更内容を事前確認可能 |
| StackSetsでマルチアカウント対応 | 複数アカウントへの一括デプロイ |
| ドリフト検出 | 手動変更を自動検出 |
| コスト | 無料 (AWS APIコールのみ課金) |
| GCAS推奨 | 政府系システムでの実績多数 |

### 1.2 スタック構成方針

- **環境別スタック**: 本番/ステージング/共通を完全分離
- **レイヤー別スタック**: Network / Security / Compute / Data に分離
- **依存関係管理**: Exportsと!ImportValueで接続
- **ネステッドスタック活用**: 複雑なリソースは分割

### 1.3 アカウント別責務

| アカウント | CloudFormation管理対象 | 責務 |
|----------|---------------------|-----|
| management-account | Organizations, SCPs | 組織全体の管理 |
| common-account | VPC, TGW, Direct Connect, Network Firewall | 共通ネットワークインフラ |
| prod-app-account | ECS, RDS, ElastiCache, ALB, S3 | 本番アプリケーションリソース |
| staging-account | ECS, RDS, ALB, S3 (縮小版) | ステージング環境 |
| operations-account | CloudWatch Logs集約, Lambda, Backup | 運用・監視リソース |
| security-account | Security Hub, GuardDuty, IAM IC | セキュリティ管理 |
| audit-account | CloudTrail, Config, S3 (ログ保管) | 監査ログ保管 |

---

## 2. ディレクトリ構造

```
infra/cloudformation/
├── README.md
├── templates/                      # 環境別テンプレート
│   ├── common/                     # 共通アカウント
│   │   ├── 01-vpc.yaml
│   │   ├── 02-transit-gateway.yaml
│   │   ├── 03-direct-connect.yaml
│   │   ├── 04-network-firewall.yaml
│   │   ├── 05-route53.yaml
│   │   ├── parameters-common.json
│   │   └── README.md
│   │
│   ├── prod/                       # 本番アカウント
│   │   ├── 01-vpc.yaml
│   │   ├── 02-security-groups.yaml
│   │   ├── 03-iam-roles.yaml
│   │   ├── 04-kms.yaml
│   │   ├── 05-s3.yaml
│   │   ├── 06-ecr.yaml
│   │   ├── 07-ecs-cluster.yaml
│   │   ├── 08-rds.yaml
│   │   ├── 09-elasticache.yaml
│   │   ├── 10-alb.yaml
│   │   ├── 11-ecs-service.yaml
│   │   ├── 12-cloudfront.yaml
│   │   ├── 13-waf.yaml
│   │   ├── 14-cloudwatch-alarms.yaml
│   │   ├── parameters-prod.json
│   │   └── README.md
│   │
│   ├── staging/                    # ステージングアカウント
│   │   ├── 01-vpc.yaml
│   │   ├── 02-security-groups.yaml
│   │   ├── 03-iam-roles.yaml
│   │   ├── 04-ecs-cluster.yaml
│   │   ├── 05-rds.yaml
│   │   ├── 06-alb.yaml
│   │   ├── 07-ecs-service.yaml
│   │   ├── parameters-staging.json
│   │   └── README.md
│   │
│   └── operations/                 # 運用アカウント
│       ├── 01-cloudwatch-logs.yaml
│       ├── 02-lambda-bedrock.yaml
│       ├── 03-sns-topics.yaml
│       ├── 04-backup-vault.yaml
│       ├── parameters-operations.json
│       └── README.md
│
└── modules/                        # 再利用可能なモジュール (ネステッドスタック用)
    ├── networking/
    │   ├── vpc-2az.yaml           # 2-AZ VPC
    │   └── vpc-3az.yaml           # 3-AZ VPC
    ├── security/
    │   ├── security-groups.yaml
    │   └── waf-rules.yaml
    ├── compute/
    │   ├── ecs-cluster.yaml
    │   └── ecs-service.yaml
    ├── database/
    │   ├── rds-aurora-postgresql.yaml
    │   └── elasticache-redis.yaml
    ├── storage/
    │   └── s3-bucket.yaml
    └── monitoring/
        ├── cloudwatch-alarms.yaml
        └── cloudwatch-dashboard.yaml
```

---

## 3. スタック管理戦略

### 3.1 スタック命名規則

```
{project}-{environment}-{layer}-{resource}

例:
- niigatacity-kaigo-prod-network-vpc
- niigatacity-kaigo-prod-compute-ecs
- niigatacity-kaigo-prod-data-rds
- niigatacity-kaigo-common-network-tgw
```

### 3.1 スタックの依存関係

```
本番環境 (prod-app-account)
│
├── 01. VPCスタック (基盤)
│   └── Export: ProdVpcId, ProdPublicSubnetIds, ProdPrivateAppSubnetIds
│
├── 02. Security Groupsスタック
│   └── Import: ProdVpcId
│   └── Export: ProdAlbSecurityGroupId, ProdEcsSecurityGroupId, ProdRdsSecurityGroupId
│
├── 03. IAM Rolesスタック
│   └── Export: EcsTaskExecutionRoleArn, EcsTaskRoleArn
│
├── 04. KMSスタック
│   └── Export: ProdRdsKmsKeyId, ProdS3KmsKeyId
│
├── 05. S3スタック
│   └── Import: ProdS3KmsKeyId
│   └── Export: ProdDocumentsBucketName
│
├── 06. ECRスタック
│   └── Export: EcrRepositoryUri
│
├── 07. ECS Clusterスタック
│   └── Export: EcsClusterName
│
├── 08. RDSスタック
│   └── Import: ProdVpcId, ProdPrivateDbSubnetIds, ProdRdsSecurityGroupId, ProdRdsKmsKeyId
│   └── Export: RdsClusterEndpoint, RdsReaderEndpoint
│
├── 09. ElastiCacheスタック
│   └── Import: ProdVpcId, ProdPrivateCacheSubnetIds, ProdCacheSecurityGroupId
│   └── Export: ElastiCacheEndpoint
│
├── 10. ALBスタック
│   └── Import: ProdVpcId, ProdPublicSubnetIds, ProdAlbSecurityGroupId
│   └── Export: AlbArn, AlbDnsName, AlbTargetGroupArn
│
├── 11. ECS Serviceスタック
│   └── Import: EcsClusterName, ProdPrivateAppSubnetIds, ProdEcsSecurityGroupId, AlbTargetGroupArn, EcsTaskExecutionRoleArn, EcsTaskRoleArn
│
└── 12-14. 監視・WAF等
```

### 3.3 スタックデプロイ順序

**本番環境の初回デプロイ順:**

1. VPC
2. Security Groups, IAM Roles, KMS (並列可)
3. S3, ECR (並列可)
4. ECS Cluster
5. RDS, ElastiCache (並列可)
6. ALB
7. ECS Service
8. CloudFront, WAF, CloudWatch Alarms (並列可)

---

## 4. テンプレート設計

### 4.1 テンプレート構造

全テンプレートは以下の構造に従います:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: >
  新潟市介護保険事業所システム - [リソース名]
  Environment: [prod/staging/common/operations]
  ManagedBy: CloudFormation

Metadata:
  AWS::CloudFormation::Interface:
    ParameterGroups:
      - Label:
          default: "Environment Configuration"
        Parameters:
          - Environment
          - ProjectName
    ParameterLabels:
      Environment:
        default: "Environment Name"

Parameters:
  Environment:
    Type: String
    Default: prod
    AllowedValues:
      - prod
      - staging
      - common
      - operations
    Description: Environment name

  ProjectName:
    Type: String
    Default: niigatacity-kaigo
    Description: Project name for resource naming and tagging

Mappings:
  # 環境別設定マップ
  EnvironmentConfig:
    prod:
      VpcCIDR: 10.1.0.0/16
    staging:
      VpcCIDR: 10.2.0.0/16

Conditions:
  IsProduction: !Equals [!Ref Environment, prod]
  IsStaging: !Equals [!Ref Environment, staging]

Resources:
  # リソース定義

Outputs:
  # Exportsで他スタックから参照可能にする
  VpcId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub '${ProjectName}-${Environment}-VpcId'
```

### 4.2 VPCテンプレート例 (本番)

**templates/prod/01-vpc.yaml:**

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: >
  新潟市介護保険事業所システム - VPC (本番環境)
  CIDR: 10.1.0.0/16, Multi-AZ (ap-northeast-1a, 1c)
  ManagedBy: CloudFormation

Parameters:
  Environment:
    Type: String
    Default: prod
    AllowedValues: [prod]

  ProjectName:
    Type: String
    Default: niigatacity-kaigo

  VpcCIDR:
    Type: String
    Default: 10.1.0.0/16
    Description: VPC CIDR block

  AvailabilityZone1:
    Type: AWS::EC2::AvailabilityZone::Name
    Default: ap-northeast-1a

  AvailabilityZone2:
    Type: AWS::EC2::AvailabilityZone::Name
    Default: ap-northeast-1c

  PublicSubnet1CIDR:
    Type: String
    Default: 10.1.1.0/24

  PublicSubnet2CIDR:
    Type: String
    Default: 10.1.2.0/24

  PrivateAppSubnet1CIDR:
    Type: String
    Default: 10.1.11.0/24

  PrivateAppSubnet2CIDR:
    Type: String
    Default: 10.1.12.0/24

  PrivateDbSubnet1CIDR:
    Type: String
    Default: 10.1.21.0/24

  PrivateDbSubnet2CIDR:
    Type: String
    Default: 10.1.22.0/24

  PrivateCacheSubnet1CIDR:
    Type: String
    Default: 10.1.31.0/24

  PrivateCacheSubnet2CIDR:
    Type: String
    Default: 10.1.32.0/24

  EnableFlowLogs:
    Type: String
    Default: 'true'
    AllowedValues: ['true', 'false']

Conditions:
  ShouldCreateFlowLogs: !Equals [!Ref EnableFlowLogs, 'true']

Resources:
  # VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCIDR
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-vpc'
        - Key: Environment
          Value: !Ref Environment
        - Key: Project
          Value: !Ref ProjectName
        - Key: ManagedBy
          Value: CloudFormation

  # Internet Gateway
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-igw'
        - Key: Environment
          Value: !Ref Environment

  InternetGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  # Public Subnets
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Ref AvailabilityZone1
      CidrBlock: !Ref PublicSubnet1CIDR
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-public-subnet-1a'
        - Key: Type
          Value: public

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Ref AvailabilityZone2
      CidrBlock: !Ref PublicSubnet2CIDR
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-public-subnet-1c'
        - Key: Type
          Value: public

  # NAT Gateways
  NatGateway1EIP:
    Type: AWS::EC2::EIP
    DependsOn: InternetGatewayAttachment
    Properties:
      Domain: vpc
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-nat-eip-1a'

  NatGateway2EIP:
    Type: AWS::EC2::EIP
    DependsOn: InternetGatewayAttachment
    Properties:
      Domain: vpc
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-nat-eip-1c'

  NatGateway1:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NatGateway1EIP.AllocationId
      SubnetId: !Ref PublicSubnet1
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-nat-gateway-1a'

  NatGateway2:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NatGateway2EIP.AllocationId
      SubnetId: !Ref PublicSubnet2
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-nat-gateway-1c'

  # Private App Subnets
  PrivateAppSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Ref AvailabilityZone1
      CidrBlock: !Ref PrivateAppSubnet1CIDR
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-app-subnet-1a'
        - Key: Type
          Value: private-app

  PrivateAppSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Ref AvailabilityZone2
      CidrBlock: !Ref PrivateAppSubnet2CIDR
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-app-subnet-1c'
        - Key: Type
          Value: private-app

  # Private DB Subnets
  PrivateDbSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Ref AvailabilityZone1
      CidrBlock: !Ref PrivateDbSubnet1CIDR
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-db-subnet-1a'
        - Key: Type
          Value: private-db

  PrivateDbSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Ref AvailabilityZone2
      CidrBlock: !Ref PrivateDbSubnet2CIDR
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-db-subnet-1c'
        - Key: Type
          Value: private-db

  # Private Cache Subnets
  PrivateCacheSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Ref AvailabilityZone1
      CidrBlock: !Ref PrivateCacheSubnet1CIDR
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-cache-subnet-1a'
        - Key: Type
          Value: private-cache

  PrivateCacheSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Ref AvailabilityZone2
      CidrBlock: !Ref PrivateCacheSubnet2CIDR
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-cache-subnet-1c'
        - Key: Type
          Value: private-cache

  # Route Tables
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-public-rt'
        - Key: Type
          Value: public

  DefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: InternetGatewayAttachment
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref PublicRouteTable

  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet2
      RouteTableId: !Ref PublicRouteTable

  # Private Route Tables (Multi-AZ)
  PrivateRouteTable1:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-rt-1a'
        - Key: Type
          Value: private

  DefaultPrivateRoute1:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway1

  PrivateAppSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateAppSubnet1
      RouteTableId: !Ref PrivateRouteTable1

  PrivateRouteTable2:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-rt-1c'
        - Key: Type
          Value: private

  DefaultPrivateRoute2:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable2
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway2

  PrivateAppSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateAppSubnet2
      RouteTableId: !Ref PrivateRouteTable2

  # DB Route Table (No NAT Gateway)
  PrivateDbRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-private-db-rt'
        - Key: Type
          Value: private-db

  PrivateDbSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateDbSubnet1
      RouteTableId: !Ref PrivateDbRouteTable

  PrivateDbSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateDbSubnet2
      RouteTableId: !Ref PrivateDbRouteTable

  # VPC Flow Logs
  FlowLogsRole:
    Type: AWS::IAM::Role
    Condition: ShouldCreateFlowLogs
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-09-09'
        Statement:
          - Effect: Allow
            Principal:
              Service: vpc-flow-logs.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: CloudWatchLogPolicy
          PolicyDocument:
            Version: '2012-09-09'
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                  - logs:DescribeLogGroups
                  - logs:DescribeLogStreams
                Resource: '*'

  FlowLogsLogGroup:
    Type: AWS::Logs::LogGroup
    Condition: ShouldCreateFlowLogs
    Properties:
      LogGroupName: !Sub '/aws/vpc/flowlogs/${ProjectName}-${Environment}'
      RetentionInDays: 30

  VPCFlowLog:
    Type: AWS::EC2::FlowLog
    Condition: ShouldCreateFlowLogs
    Properties:
      ResourceType: VPC
      ResourceId: !Ref VPC
      TrafficType: ALL
      LogDestinationType: cloud-watch-logs
      LogGroupName: !Ref FlowLogsLogGroup
      DeliverLogsPermissionArn: !GetAtt FlowLogsRole.Arn
      Tags:
        - Key: Name
          Value: !Sub '${ProjectName}-${Environment}-vpc-flow-logs'

  # VPC Endpoints (Gateway)
  S3Endpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.s3'
      RouteTableIds:
        - !Ref PrivateRouteTable1
        - !Ref PrivateRouteTable2
        - !Ref PrivateDbRouteTable

  DynamoDBEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.dynamodb'
      RouteTableIds:
        - !Ref PrivateRouteTable1
        - !Ref PrivateRouteTable2

Outputs:
  VpcId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub '${ProjectName}-${Environment}-VpcId'

  VpcCIDR:
    Description: VPC CIDR block
    Value: !GetAtt VPC.CidrBlock
    Export:
      Name: !Sub '${ProjectName}-${Environment}-VpcCIDR'

  PublicSubnet1Id:
    Description: Public Subnet 1 ID (ap-northeast-1a)
    Value: !Ref PublicSubnet1
    Export:
      Name: !Sub '${ProjectName}-${Environment}-PublicSubnet1Id'

  PublicSubnet2Id:
    Description: Public Subnet 2 ID (ap-northeast-1c)
    Value: !Ref PublicSubnet2
    Export:
      Name: !Sub '${ProjectName}-${Environment}-PublicSubnet2Id'

  PrivateAppSubnet1Id:
    Description: Private App Subnet 1 ID (ap-northeast-1a)
    Value: !Ref PrivateAppSubnet1
    Export:
      Name: !Sub '${ProjectName}-${Environment}-PrivateAppSubnet1Id'

  PrivateAppSubnet2Id:
    Description: Private App Subnet 2 ID (ap-northeast-1c)
    Value: !Ref PrivateAppSubnet2
    Export:
      Name: !Sub '${ProjectName}-${Environment}-PrivateAppSubnet2Id'

  PrivateDbSubnet1Id:
    Description: Private DB Subnet 1 ID (ap-northeast-1a)
    Value: !Ref PrivateDbSubnet1
    Export:
      Name: !Sub '${ProjectName}-${Environment}-PrivateDbSubnet1Id'

  PrivateDbSubnet2Id:
    Description: Private DB Subnet 2 ID (ap-northeast-1c)
    Value: !Ref PrivateDbSubnet2
    Export:
      Name: !Sub '${ProjectName}-${Environment}-PrivateDbSubnet2Id'

  PrivateCacheSubnet1Id:
    Description: Private Cache Subnet 1 ID (ap-northeast-1a)
    Value: !Ref PrivateCacheSubnet1
    Export:
      Name: !Sub '${ProjectName}-${Environment}-PrivateCacheSubnet1Id'

  PrivateCacheSubnet2Id:
    Description: Private Cache Subnet 2 ID (ap-northeast-1c)
    Value: !Ref PrivateCacheSubnet2
    Export:
      Name: !Sub '${ProjectName}-${Environment}-PrivateCacheSubnet2Id'
```

---

## 5. パラメータ管理

### 5.1 パラメータファイル

**templates/prod/parameters-prod.json:**

```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "prod"
  },
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "niigatacity-kaigo"
  },
  {
    "ParameterKey": "VpcCIDR",
    "ParameterValue": "10.1.0.0/16"
  },
  {
    "ParameterKey": "AvailabilityZone1",
    "ParameterValue": "ap-northeast-1a"
  },
  {
    "ParameterKey": "AvailabilityZone2",
    "ParameterValue": "ap-northeast-1c"
  },
  {
    "ParameterKey": "EnableFlowLogs",
    "ParameterValue": "true"
  }
]
```

### 5.2 機密情報の管理

機密情報はSecrets Managerを使用し、動的参照で取得:

```yaml
MasterUserPassword: !Sub '{{resolve:secretsmanager:${Environment}/db/master-password:SecretString:password}}'
```

**事前にSecrets Managerに作成:**

```bash
aws secretsmanager create-secret \
  --name prod/db/master-password \
  --secret-string '{"username":"pgadmin","password":"CHANGE_ME"}' \
  --region ap-northeast-1
```

---

## 6. Change Set運用

### 6.1 Change Set作成フロー

```
開発者がテンプレート修正
    ↓
Pull Request作成
    ↓
GitHub Actions: Change Set作成 (自動)
    ↓
Change Set内容をPRにコメント (自動)
    ↓
レビュー担当者がChange Setを確認
    ↓
PRマージ
    ↓
GitHub Actions: Change Set実行 (本番は手動承認)
```

### 6.2 Change Set作成コマンド

```bash
aws cloudformation create-change-set \
  --stack-name niigatacity-kaigo-prod-network-vpc \
  --change-set-name update-$(date +%Y%m%d-%H%M%S) \
  --template-body file://01-vpc.yaml \
  --parameters file://parameters-prod.json \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-1

# Change Set確認
aws cloudformation describe-change-set \
  --stack-name niigatacity-kaigo-prod-network-vpc \
  --change-set-name update-20251105-120000 \
  --region ap-northeast-1

# Change Set実行
aws cloudformation execute-change-set \
  --stack-name niigatacity-kaigo-prod-network-vpc \
  --change-set-name update-20251105-120000 \
  --region ap-northeast-1
```

---

## 7. CI/CD統合

### 7.1 GitHub Actions Workflow (CloudFormation Deploy)

```.github/workflows/cloudformation-deploy.yml```

```yaml
name: CloudFormation Deploy

on:
  push:
    branches:
      - main
    paths:
      - 'infra/cloudformation/**'

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    name: Deploy CloudFormation Stack
    runs-on: ubuntu-latest
    environment: production
    strategy:
      matrix:
        stack:
          - name: niigatacity-kaigo-prod-network-vpc
            template: infra/cloudformation/templates/prod/01-vpc.yaml
            parameters: infra/cloudformation/templates/prod/parameters-prod.json
      max-parallel: 1  # 順次実行

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::555555555555:role/GitHubActionsCloudFormationRole
          aws-region: ap-northeast-1

      - name: Validate Template
        run: |
          aws cloudformation validate-template \
            --template-body file://${{ matrix.stack.template }}

      - name: Create Change Set
        id: changeset
        run: |
          CHANGE_SET_NAME="update-$(date +%Y%m%d-%H%M%S)"
          echo "change_set_name=$CHANGE_SET_NAME" >> $GITHUB_OUTPUT

          aws cloudformation create-change-set \
            --stack-name ${{ matrix.stack.name }} \
            --change-set-name $CHANGE_SET_NAME \
            --template-body file://${{ matrix.stack.template }} \
            --parameters file://${{ matrix.stack.parameters }} \
            --capabilities CAPABILITY_IAM \
            --region ap-northeast-1

      - name: Wait for Change Set Creation
        run: |
          aws cloudformation wait change-set-create-complete \
            --stack-name ${{ matrix.stack.name }} \
            --change-set-name ${{ steps.changeset.outputs.change_set_name }} \
            --region ap-northeast-1

      - name: Describe Change Set
        id: describe
        run: |
          aws cloudformation describe-change-set \
            --stack-name ${{ matrix.stack.name }} \
            --change-set-name ${{ steps.changeset.outputs.change_set_name }} \
            --region ap-northeast-1

      - name: Execute Change Set
        run: |
          aws cloudformation execute-change-set \
            --stack-name ${{ matrix.stack.name }} \
            --change-set-name ${{ steps.changeset.outputs.change_set_name }} \
            --region ap-northeast-1

      - name: Wait for Stack Update
        run: |
          aws cloudformation wait stack-update-complete \
            --stack-name ${{ matrix.stack.name }} \
            --region ap-northeast-1
```

---

## 8. セキュリティベストプラクティス

### 8.1 テンプレートセキュリティ

| 項目 | 実装 |
|-----|------|
| 機密情報 | Secrets Manager動的参照を使用、ハードコード禁止 |
| IAMロール | 最小権限の原則、ManagedPolicyではなくInline Policy |
| 暗号化 | 全リソースでKMS暗号化有効化 |
| パブリックアクセス | S3/RDSのパブリックアクセス明示的に無効化 |
| タグ付け | 全リソースに Environment, Project, ManagedBy タグ必須 |

### 8.2 Change Setレビューチェックリスト

- [ ] 削除されるリソースはないか
- [ ] 置き換え (Replacement: True) されるリソースはないか
- [ ] セキュリティグループの変更内容は適切か
- [ ] IAMロール/ポリシーの変更内容は適切か
- [ ] パラメータの変更内容は適切か

### 8.3 ドリフト検出

定期的にドリフト検出を実行し、手動変更を検知:

```bash
# ドリフト検出開始
aws cloudformation detect-stack-drift \
  --stack-name niigatacity-kaigo-prod-network-vpc

# 結果確認
aws cloudformation describe-stack-resource-drifts \
  --stack-name niigatacity-kaigo-prod-network-vpc
```

---

## 変更履歴

| バージョン | 日付 | 変更内容 | 作成者 |
|----------|------|---------|-------|
| 1.0.0 | 2025-11-05 | 初版作成 (Terraformから移行) | Claude |

---

**次のドキュメント:** [CI/CD設計書](03_cicd_design.md)
