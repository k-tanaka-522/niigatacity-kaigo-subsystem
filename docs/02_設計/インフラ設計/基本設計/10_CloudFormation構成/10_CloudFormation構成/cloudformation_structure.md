# CloudFormation ファイル分割3原則とディレクトリ構造

**作成日**: 2025-11-09
**更新日**: 2025-11-09
**対象環境**: 本番（Production）、ステージング（Staging）

---

## 1. 目的

このドキュメントでは、新潟市介護保険事業所システムにおける CloudFormation テンプレートのファイル分割方針とディレクトリ構造を定義します。

**背景**:
- メンテナンス性の向上
- 変更リスクの最小化
- チームでの並行作業の実現
- 可読性の確保

**技術標準準拠**:
- `.claude/docs/40_standards/42_infra/iac/cloudformation.md` に準拠

---

## 2. ファイル分割の3原則

CloudFormation テンプレートのファイル分割は、以下の3原則に基づいて判断します。

### 原則1: AWS コンソールの分け方（基本）

**AWS コンソールで別メニュー → 別ファイル**

| リソース | 判定 | 理由 |
|---------|------|------|
| VPC と Internet Gateway | 同じファイル | VPC作成時に一緒に作る、密結合 |
| VPC と Subnets | 別ファイル | 別メニュー、Subnetsは後から追加する可能性 |
| ALB と Target Group と Listener | 同じファイル | ALB配下で一緒に操作 |
| ECS Cluster と ECS Service | 別ファイル | 別メニュー、変更頻度が異なる |

**理由**: AWS コンソールの構造は、AWS が推奨するリソースの論理的なまとまりを反映しています。

### 原則2: ライフサイクル（変更頻度）

**初回のみ作成 vs 頻繁に変更 → 分ける**

| 更新頻度 | リソース例 | 分離推奨 |
|---------|----------|--------|
| 年単位 | VPC, Subnet, Route Table | network/ スタック |
| 月単位 | RDS, ElastiCache, S3 | database/ スタック |
| 週単位 | ECS Service, ALB, Auto Scaling | compute-base/ スタック |
| 日単位 | ECS Task Definition | compute-app/ スタック |

**新潟市プロジェクトでの適用例**:
- **VPC・Subnet**: 初回のみ作成、慎重に変更（年単位）
- **RDS**: たまに変更（月単位）
- **ECS Cluster**: 初回のみ作成（月単位）
- **ECS Task Definition**: 頻繁に変更（週単位）

**理由**: 変更頻度が異なるリソースを分けることで、変更リスクを最小化できます。

### 原則3: 設定数（増減の可能性）

**1個で固定 vs 継続的に増える → 分ける**

| リソース | 設定数 | 判定 |
|---------|-------|------|
| VPC | 1個（固定） | 同じファイルでOK |
| Subnets | 4個 → 増える可能性 | 別ファイル |
| Security Groups | 3個 → 激増する | ディレクトリで分割 |
| CloudWatch Alarms | 数個 → 激増する | サービス別にファイル分割 |

**増えやすいリソースの例**:
- Security Groups → `templates/network/security-groups/alb-sg.yaml`, `ecs-sg.yaml`
- CloudWatch Alarms → `templates/monitoring/alarms-ecs.yaml`, `alarms-rds.yaml`

### 判断フロー

```
1. AWS コンソールで別メニュー？
   ├─ Yes → 分割候補
   └─ No → 同じファイル候補

2. ライフサイクルが異なる？
   ├─ Yes → 分割推奨
   └─ No → 次へ

3. 設定が継続的に増える？
   ├─ Yes → 分割推奨（ディレクトリ化も検討）
   └─ No → 同じファイルでOK
```

---

## 3. 新潟市プロジェクトのディレクトリ構造

### 3.1 推奨構造（ライフサイクル別スタック + 再利用可能テンプレート）

```
infra/cloudformation/
├── README.md                           # 全体インデックス、3原則の説明、よくある変更の対応表
├── stacks/                             # ライフサイクル別スタック定義（デプロイ単位）⭐
│   ├── 01-audit/                       # 年単位（初回のみ、慎重に変更）
│   │   ├── main.yaml                   # CloudTrail, AWS Config, GuardDuty
│   │   └── README.md                   # スタック分割の理由、デプロイ戦略
│   ├── 02-network/                     # 年単位（初回のみ、慎重に変更）
│   │   ├── main.yaml                   # 親スタック（templates/network/*.yaml を参照）
│   │   └── README.md
│   ├── 03-security/                    # 月単位（たまに変更）
│   │   ├── main.yaml                   # WAF, Security Hub, KMS
│   │   └── README.md
│   ├── 04-database/                    # 月単位（たまに変更）
│   │   ├── main.yaml                   # RDS, ElastiCache
│   │   └── README.md
│   ├── 05-storage/                     # 月単位（たまに変更）
│   │   ├── main.yaml                   # S3, CloudFront
│   │   └── README.md
│   ├── 06-compute-base/                # 月単位（ECS Cluster, ALB等）
│   │   ├── main.yaml                   # ECS Cluster, ALB, ECR
│   │   └── README.md
│   ├── 07-compute-app/                 # 週単位（Task Definition, Service、頻繁に変更）
│   │   ├── main.yaml                   # ECS Task Definition, ECS Service
│   │   └── README.md
│   └── 08-monitoring/                  # 月単位（たまに変更）
│       ├── main.yaml                   # CloudWatch Logs, Alarms, SNS
│       └── README.md
├── templates/                          # 再利用可能なネストスタック（実体）⭐
│   ├── audit/
│   │   ├── cloudtrail.yaml             # CloudTrail（証跡記録）
│   │   ├── aws-config.yaml             # AWS Config（コンプライアンス監視）
│   │   └── guardduty.yaml              # GuardDuty（脅威検出）
│   ├── network/
│   │   ├── vpc-and-igw.yaml            # VPC + Internet Gateway（密結合）
│   │   ├── subnets.yaml                # Subnets（別メニュー、たまに追加）
│   │   ├── nat-gateways.yaml           # NAT Gateway（別メニュー、高額）
│   │   ├── route-tables.yaml           # Route Tables（別メニュー、たまに変更）
│   │   ├── transit-gateway.yaml        # Transit Gateway（ハブ&スポーク）★ 高額・Direct Connect回線手配必要のため実装保留
│   │   └── security-groups/            # ★ ディレクトリ（激増する）
│   │       ├── alb-sg.yaml
│   │       ├── ecs-sg.yaml
│   │       └── rds-sg.yaml
│   ├── security/
│   │   ├── waf.yaml                    # WAF（WebACL + Rules）
│   │   ├── security-hub.yaml           # Security Hub
│   │   └── kms.yaml                    # KMS（暗号化キー）
│   ├── database/
│   │   ├── rds-mysql.yaml              # RDS MySQL Multi-AZ
│   │   └── elasticache-redis.yaml      # ElastiCache Redis
│   ├── storage/
│   │   ├── s3-buckets.yaml             # S3（ドキュメント保管、ログ保管）
│   │   └── cloudfront.yaml             # CloudFront（静的コンテンツ配信）
│   ├── compute/
│   │   ├── ecr-repositories.yaml       # ECR（Docker イメージレジストリ）
│   │   ├── ecs-cluster.yaml            # ECS Cluster（初回のみ）
│   │   ├── ecs-task-backend.yaml       # ECS Task Definition（.NET Core API）
│   │   ├── ecs-service-backend.yaml    # ECS Service（Backend）
│   │   ├── ecs-task-frontend.yaml      # ECS Task Definition（Next.js）
│   │   ├── ecs-service-frontend.yaml   # ECS Service（Frontend）
│   │   └── alb.yaml                    # ALB + Target Group + Listener（密結合）
│   └── monitoring/
│       ├── cloudwatch-log-groups.yaml  # Log Groups（別メニュー、増える）
│       ├── cloudwatch-alarms-ecs.yaml  # Alarms（激増、サービス別）
│       ├── cloudwatch-alarms-rds.yaml
│       ├── cloudwatch-alarms-alb.yaml
│       └── sns-topics.yaml             # SNS（アラート通知）
└── parameters/                         # 環境差分を集約 ⭐
    ├── production.json                 # 本番環境パラメーター
    └── staging.json                    # ステージング環境パラメーター
```

### 3.2 3つのディレクトリの役割

| ディレクトリ | 役割 | 分け方 | 例 |
|------------|------|--------|---|
| **stacks/** | デプロイ単位（親スタック） | ライフサイクル（変更頻度） | 02-network（年1回）、07-compute-app（週数回） |
| **templates/** | 実装（ネストスタック） | 機能別 + 3原則 | network/vpc-and-igw.yaml、compute/ecs-task-backend.yaml |
| **parameters/** | 環境差分 | 環境別 | production.json、staging.json |

### 3.3 stacks/ と templates/ の対応関係

**stacks/02-network/main.yaml（親スタック）:**

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Network Stack - VPC, Subnets, NAT Gateway, Route Tables'

Parameters:
  Environment:
    Type: String
    AllowedValues: [production, staging]
  VpcCidr:
    Type: String
  TemplateBucket:
    Type: String
    Description: 'S3 bucket for nested stack templates'

Resources:
  # VPC + Internet Gateway（密結合、初回のみ）
  VPCStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplateBucket}/templates/network/vpc-and-igw.yaml'
      Parameters:
        Environment: !Ref Environment
        VpcCidr: !Ref VpcCidr

  # Subnets（別メニュー、たまに追加）
  SubnetsStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplateBucket}/templates/network/subnets.yaml'
      Parameters:
        VpcId: !GetAtt VPCStack.Outputs.VpcId
        VpcCidr: !Ref VpcCidr

  # NAT Gateway（高額、初回のみ）
  NATGatewaysStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplateBucket}/templates/network/nat-gateways.yaml'
      Parameters:
        PublicSubnetIds: !GetAtt SubnetsStack.Outputs.PublicSubnetIds

  # Route Tables（たまに変更）
  RouteTablesStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://s3.amazonaws.com/${TemplateBucket}/templates/network/route-tables.yaml'
      Parameters:
        VpcId: !GetAtt VPCStack.Outputs.VpcId
        InternetGatewayId: !GetAtt VPCStack.Outputs.InternetGatewayId
        NATGatewayIds: !GetAtt NATGatewaysStack.Outputs.NATGatewayIds

Outputs:
  VpcId:
    Value: !GetAtt VPCStack.Outputs.VpcId
    Export:
      Name: !Sub '${AWS::StackName}-VpcId'

  PrivateSubnetIds:
    Value: !GetAtt SubnetsStack.Outputs.PrivateSubnetIds
    Export:
      Name: !Sub '${AWS::StackName}-PrivateSubnetIds'
```

**templates/network/vpc-and-igw.yaml（ネストスタック、再利用可能）:**

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'VPC and Internet Gateway (reusable nested stack)'

Parameters:
  Environment:
    Type: String
  VpcCidr:
    Type: String

Resources:
  ServiceVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub 'niigata-kaigo-${Environment}-vpc'
        - Key: Environment
          Value: !Ref Environment

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub 'niigata-kaigo-${Environment}-igw'

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref ServiceVPC
      InternetGatewayId: !Ref InternetGateway

Outputs:
  VpcId:
    Value: !Ref ServiceVPC
    Export:
      Name: !Sub '${AWS::StackName}-VpcId'

  InternetGatewayId:
    Value: !Ref InternetGateway
    Export:
      Name: !Sub '${AWS::StackName}-InternetGatewayId'
```

---

## 4. クロススタック参照（Export/Import）

### 4.1 基本パターン

**Export（出力する側）:**

```yaml
Outputs:
  VpcId:
    Value: !Ref VPC
    Export:
      Name: !Sub 'niigata-kaigo-${Environment}-VpcId'

  PrivateSubnetIds:
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
    Export:
      Name: !Sub 'niigata-kaigo-${Environment}-PrivateSubnetIds'
```

**Import（参照する側）:**

```yaml
Resources:
  ECSService:
    Type: AWS::ECS::Service
    Properties:
      NetworkConfiguration:
        AwsvpcConfiguration:
          Subnets: !Split
            - ','
            - !ImportValue
                Fn::Sub: 'niigata-kaigo-${Environment}-PrivateSubnetIds'
```

### 4.2 新潟市プロジェクトでのExport命名規則

| スタック | Export名 | 説明 |
|---------|---------|------|
| 02-network | `niigata-kaigo-${Environment}-VpcId` | VPC ID |
| 02-network | `niigata-kaigo-${Environment}-PrivateSubnetIds` | プライベートサブネット（カンマ区切り） |
| 02-network | `niigata-kaigo-${Environment}-PublicSubnetIds` | パブリックサブネット（カンマ区切り） |
| 02-network | `niigata-kaigo-${Environment}-ALBSecurityGroupId` | ALB Security Group ID |
| 02-network | `niigata-kaigo-${Environment}-ECSSecurityGroupId` | ECS Security Group ID |
| 06-compute-base | `niigata-kaigo-${Environment}-ECSClusterArn` | ECS Cluster ARN |
| 06-compute-base | `niigata-kaigo-${Environment}-ALBTargetGroupArn` | ALB Target Group ARN |

---

## 5. parameters/ ディレクトリの構成

### 5.1 環境別パラメーターファイル

**parameters/production.json:**

```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "production"
  },
  {
    "ParameterKey": "VpcCidr",
    "ParameterValue": "10.0.0.0/16"
  },
  {
    "ParameterKey": "PublicSubnet1Cidr",
    "ParameterValue": "10.0.1.0/24"
  },
  {
    "ParameterKey": "PublicSubnet2Cidr",
    "ParameterValue": "10.0.2.0/24"
  },
  {
    "ParameterKey": "PrivateSubnet1Cidr",
    "ParameterValue": "10.0.11.0/24"
  },
  {
    "ParameterKey": "PrivateSubnet2Cidr",
    "ParameterValue": "10.0.12.0/24"
  },
  {
    "ParameterKey": "DBInstanceClass",
    "ParameterValue": "db.t3.medium"
  },
  {
    "ParameterKey": "ECSTaskCpu",
    "ParameterValue": "512"
  },
  {
    "ParameterKey": "ECSTaskMemory",
    "ParameterValue": "1024"
  }
]
```

**parameters/staging.json:**

```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "staging"
  },
  {
    "ParameterKey": "VpcCidr",
    "ParameterValue": "10.1.0.0/16"
  },
  {
    "ParameterKey": "PublicSubnet1Cidr",
    "ParameterValue": "10.1.1.0/24"
  },
  {
    "ParameterKey": "PublicSubnet2Cidr",
    "ParameterValue": "10.1.2.0/24"
  },
  {
    "ParameterKey": "PrivateSubnet1Cidr",
    "ParameterValue": "10.1.11.0/24"
  },
  {
    "ParameterKey": "PrivateSubnet2Cidr",
    "ParameterValue": "10.1.12.0/24"
  },
  {
    "ParameterKey": "DBInstanceClass",
    "ParameterValue": "db.t3.small"
  },
  {
    "ParameterKey": "ECSTaskCpu",
    "ParameterValue": "256"
  },
  {
    "ParameterKey": "ECSTaskMemory",
    "ParameterValue": "512"
  }
]
```

### 5.2 環境差分管理のポイント

| 項目 | 本番（Production） | ステージング（Staging） | 理由 |
|-----|------------------|---------------------|------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | IP アドレス重複回避 |
| DB Instance | db.t3.medium | db.t3.small | コスト最適化 |
| ECS Task CPU | 512 | 256 | リソース最適化 |
| Multi-AZ | true | false | 可用性 vs コスト |
| Auto Scaling | 2-10 | 1-2 | スケーリング戦略 |

---

## 6. スタック分割の判断例（新潟市プロジェクト）

### 6.1 Network スタック

| リソース | コンソール | ライフサイクル | 設定数 | 判定 | ファイル配置 |
|---------|-----------|--------------|--------|------|------------|
| VPC + IGW | 密結合 | 初回のみ | 1個 | 同じファイル | templates/network/vpc-and-igw.yaml |
| Subnets | 別メニュー | たまに追加 | 4個→増える | 別ファイル | templates/network/subnets.yaml |
| NAT Gateway | 別メニュー | 初回のみ | 2個 | 別ファイル | templates/network/nat-gateways.yaml |
| Route Tables | 別メニュー | たまに変更 | 4個 | 別ファイル | templates/network/route-tables.yaml |
| Security Groups | 別メニュー | 継続的に追加 | 3個→激増 | ディレクトリ | templates/network/security-groups/ |

### 6.2 Compute スタック

| リソース | コンソール | ライフサイクル | 設定数 | 判定 | ファイル配置 |
|---------|-----------|--------------|--------|------|------------|
| ECS Cluster | 別メニュー | 初回のみ | 1個 | 別ファイル | templates/compute/ecs-cluster.yaml |
| ECS Task Definition | 同じメニュー | 頻繁に変更 | 増える | サービス別 | templates/compute/ecs-task-backend.yaml |
| ECS Service | 同じメニュー | たまに変更 | 増える | サービス別 | templates/compute/ecs-service-backend.yaml |
| ALB + TG + Listener | ALB配下 | たまに変更 | 1個 | 同じファイル | templates/compute/alb.yaml |

### 6.3 Database スタック

| リソース | コンソール | ライフサイクル | 設定数 | 判定 | ファイル配置 |
|---------|-----------|--------------|--------|------|------------|
| RDS MySQL | 別メニュー | たまに変更 | 1個 | 別ファイル | templates/database/rds-mysql.yaml |
| ElastiCache Redis | 別メニュー | たまに変更 | 1個 | 別ファイル | templates/database/elasticache-redis.yaml |

---

## 7. まとめ

### 7.1 ファイル分割3原則（再掲）

1. **AWS コンソールの分け方**: 別メニュー → 別ファイル
2. **ライフサイクル**: 変更頻度が異なる → 分ける
3. **設定数**: 継続的に増える → 分ける

### 7.2 ディレクトリ構造（再掲）

- **stacks/**: ライフサイクル別のデプロイ単位（親スタック）
- **templates/**: 再利用可能なネストスタック（実体）
- **parameters/**: 環境差分を集約（production.json, staging.json）

### 7.3 実装フェーズでの注意事項

1. **技術標準準拠**: `.claude/docs/40_standards/42_infra/iac/cloudformation.md` を参照
2. **Change Sets 必須**: dry-run による安全なデプロイ
3. **クロススタック参照**: Export/Import で依存関係を明示
4. **環境差分管理**: parameters/ で環境別パラメーターを管理

---

**関連ドキュメント**:
- [deployment_strategy.md](./deployment_strategy.md) - デプロイ戦略
- [stack_lifecycle.md](./stack_lifecycle.md) - スタックライフサイクル管理
- `.claude/docs/40_standards/42_infra/iac/cloudformation.md` - CloudFormation 技術標準
