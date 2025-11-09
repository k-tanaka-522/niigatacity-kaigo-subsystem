# CloudFormation実装方針

## 文書管理情報

| 項目 | 内容 |
|------|------|
| 文書名 | CloudFormation実装方針 |
| バージョン | 1.0 |
| 作成日 | 2025-11-05 |
| 最終更新日 | 2025-11-05 |
| ステータス | Draft |

---

## 1. ファイル分割3原則

### 原則1: ライフサイクルで分割

**定義**: リソースの変更頻度・ライフサイクルが異なるものは別スタックに分割する

**例**:
- **VPCスタック**: ほぼ変更しない（インフラ基盤）
- **ECSスタック**: アプリケーションデプロイで頻繁に変更
- **RDSスタック**: データベースは慎重に変更（ダウンタイムあり）

**具体例**:
```
infrastructure/
  ├── vpc-stack.yaml              # VPC、サブネット（変更頻度: 低）
  ├── tgw-stack.yaml              # Transit Gateway（変更頻度: 低）
  └── dx-stack.yaml               # Direct Connect（変更頻度: 低）

application/
  ├── ecs-stack.yaml              # ECS、タスク定義（変更頻度: 高）
  ├── alb-stack.yaml              # ALB、ターゲットグループ（変更頻度: 中）
  └── ecr-stack.yaml              # ECR（変更頻度: 低）

data/
  ├── rds-stack.yaml              # RDS（変更頻度: 低、慎重に変更）
  └── elasticache-stack.yaml      # ElastiCache（変更頻度: 低）
```

---

### 原則2: 責務で分割

**定義**: 異なる責務・役割を持つリソースは別スタックに分割する

**例**:
- **ネットワーク層**: VPC、サブネット、ルートテーブル
- **コンピューティング層**: ECS、ALB、Auto Scaling
- **データ層**: RDS、ElastiCache、S3
- **セキュリティ層**: IAM、Security Groups、WAF
- **監視層**: CloudWatch、CloudTrail、AWS Config

**具体例**:
```
cloudformation/
  ├── network/                    # ネットワーク層
  │   ├── vpc-stack.yaml
  │   ├── tgw-stack.yaml
  │   └── dx-stack.yaml
  │
  ├── compute/                    # コンピューティング層
  │   ├── ecs-stack.yaml
  │   ├── alb-stack.yaml
  │   └── ecr-stack.yaml
  │
  ├── data/                       # データ層
  │   ├── rds-stack.yaml
  │   ├── elasticache-stack.yaml
  │   └── s3-stack.yaml
  │
  ├── security/                   # セキュリティ層
  │   ├── iam-stack.yaml
  │   ├── sg-stack.yaml
  │   └── waf-stack.yaml
  │
  └── monitoring/                 # 監視層
      ├── cloudwatch-stack.yaml
      ├── cloudtrail-stack.yaml
      └── config-stack.yaml
```

---

### 原則3: 依存関係で分割

**定義**: 依存関係が明確に分離できるものは別スタックに分割する

**例**:
- VPCスタック（基盤）
  ↓
- サブネットスタック（VPCに依存）
  ↓
- Security Groupスタック（VPCに依存）
  ↓
- ECSスタック（Security Groupに依存）

**具体例**:
```yaml
# vpc-stack.yaml（依存なし）
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.1.0.0/16

Outputs:
  VPCId:
    Value: !Ref VPC
    Export:
      Name: !Sub '${AWS::StackName}-VPCId'

---

# subnet-stack.yaml（VPCに依存）
Parameters:
  VPCStackName:
    Type: String
    Default: vpc-stack

Resources:
  PublicSubnet1a:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !ImportValue
        Fn::Sub: '${VPCStackName}-VPCId'
      CidrBlock: 10.1.1.0/24

Outputs:
  PublicSubnet1aId:
    Value: !Ref PublicSubnet1a
    Export:
      Name: !Sub '${AWS::StackName}-PublicSubnet1aId'

---

# ecs-stack.yaml（サブネット、Security Groupに依存）
Parameters:
  SubnetStackName:
    Type: String
    Default: subnet-stack
  SGStackName:
    Type: String
    Default: sg-stack

Resources:
  ECSService:
    Type: AWS::ECS::Service
    Properties:
      NetworkConfiguration:
        AwsvpcConfiguration:
          Subnets:
            - !ImportValue
              Fn::Sub: '${SubnetStackName}-PrivateAppSubnet1aId'
            - !ImportValue
              Fn::Sub: '${SubnetStackName}-PrivateAppSubnet1cId'
          SecurityGroups:
            - !ImportValue
              Fn::Sub: '${SGStackName}-ECSSecurityGroupId'
```

---

## 2. スタック分割設計

### 2.1 本番環境スタック構成

```
cloudformation/production/
├── 01_foundation/                      # 基盤層（変更頻度: 極低）
│   ├── organizations-stack.yaml        # AWS Organizations
│   ├── scp-stack.yaml                  # Service Control Policies
│   └── iam-roles-stack.yaml            # IAMロール（基本）
│
├── 02_network/                         # ネットワーク層（変更頻度: 低）
│   ├── vpc-core-stack.yaml             # VPC、IGW、DHCP Options
│   ├── subnets-stack.yaml              # サブネット
│   ├── route-tables-stack.yaml         # ルートテーブル
│   ├── nat-gateways-stack.yaml         # NAT Gateway
│   ├── vpc-endpoints-stack.yaml        # VPC Endpoints
│   ├── vpc-flowlogs-stack.yaml         # VPC Flow Logs
│   ├── tgw-core-stack.yaml             # Transit Gateway本体
│   ├── tgw-attachments-stack.yaml      # TGW Attachments
│   ├── tgw-route-tables-stack.yaml     # TGWルートテーブル
│   ├── dx-gateway-stack.yaml           # Direct Connect Gateway
│   └── dx-connections-stack.yaml       # Direct Connect接続
│
├── 03_security/                        # セキュリティ層（変更頻度: 中）
│   ├── sg-alb-stack.yaml               # ALB Security Group
│   ├── sg-ecs-stack.yaml               # ECS Security Group
│   ├── sg-rds-stack.yaml               # RDS Security Group
│   ├── sg-elasticache-stack.yaml       # ElastiCache Security Group
│   ├── waf-stack.yaml                  # AWS WAF
│   ├── kms-stack.yaml                  # KMS Keys
│   ├── secrets-manager-stack.yaml      # Secrets Manager
│   └── cognito-stack.yaml              # Amazon Cognito
│
├── 04_compute/                         # コンピューティング層（変更頻度: 高）
│   ├── ecr-stack.yaml                  # ECR
│   ├── alb-stack.yaml                  # ALB、ターゲットグループ
│   ├── ecs-cluster-stack.yaml          # ECSクラスター
│   ├── ecs-task-definition-stack.yaml  # タスク定義
│   ├── ecs-service-stack.yaml          # ECSサービス
│   └── autoscaling-stack.yaml          # Auto Scaling
│
├── 05_data/                            # データ層（変更頻度: 低）
│   ├── rds-subnet-group-stack.yaml     # RDS サブネットグループ
│   ├── rds-parameter-group-stack.yaml  # RDS パラメータグループ
│   ├── rds-option-group-stack.yaml     # RDS オプショングループ
│   ├── rds-instance-stack.yaml         # RDS インスタンス
│   ├── elasticache-subnet-group-stack.yaml
│   ├── elasticache-parameter-group-stack.yaml
│   └── elasticache-cluster-stack.yaml  # ElastiCache クラスター
│
├── 06_storage/                         # ストレージ層（変更頻度: 中）
│   ├── s3-buckets-stack.yaml           # S3 バケット
│   ├── s3-lifecycle-stack.yaml         # S3 ライフサイクルポリシー
│   └── cloudfront-stack.yaml           # CloudFront
│
├── 07_monitoring/                      # 監視層（変更頻度: 中）
│   ├── cloudwatch-alarms-stack.yaml    # CloudWatch アラーム
│   ├── cloudwatch-dashboards-stack.yaml # CloudWatch ダッシュボード
│   ├── cloudwatch-logs-stack.yaml      # CloudWatch Logsグループ
│   ├── cloudtrail-stack.yaml           # CloudTrail
│   ├── config-stack.yaml               # AWS Config
│   └── sns-topics-stack.yaml           # SNS トピック
│
├── 08_backup/                          # バックアップ層（変更頻度: 低）
│   ├── backup-vault-stack.yaml         # AWS Backup Vault
│   ├── backup-plan-stack.yaml          # AWS Backup Plan
│   └── backup-selection-stack.yaml     # Backup Selection
│
└── 09_dns/                             # DNS層（変更頻度: 中）
    └── route53-stack.yaml              # Route 53 Private Hosted Zone
```

**スタック総数**: 約45スタック

---

### 2.2 ステージング環境スタック構成

ステージング環境は本番環境のサブセット（一部省略）

```
cloudformation/staging/
├── 02_network/
│   ├── vpc-core-stack.yaml
│   ├── subnets-stack.yaml
│   ├── route-tables-stack.yaml
│   ├── nat-gateways-stack.yaml         # 1AZのみ
│   ├── vpc-endpoints-stack.yaml        # 最小限（ECR、Secrets Manager）
│   ├── vpc-flowlogs-stack.yaml         # 保持期間30日
│   ├── tgw-attachments-stack.yaml      # TGW本体は本番と共有
│   └── tgw-route-tables-stack.yaml
│
├── 03_security/
│   ├── sg-alb-stack.yaml
│   ├── sg-ecs-stack.yaml
│   ├── sg-rds-stack.yaml
│   ├── waf-stack.yaml
│   ├── kms-stack.yaml
│   ├── secrets-manager-stack.yaml
│   └── cognito-stack.yaml
│
├── 04_compute/
│   ├── ecr-stack.yaml                  # 本番と共有の可能性
│   ├── alb-stack.yaml
│   ├── ecs-cluster-stack.yaml
│   ├── ecs-task-definition-stack.yaml  # T系インスタンス
│   ├── ecs-service-stack.yaml
│   └── autoscaling-stack.yaml          # 最小1、最大3
│
├── 05_data/
│   ├── rds-subnet-group-stack.yaml
│   ├── rds-parameter-group-stack.yaml
│   ├── rds-instance-stack.yaml         # Single-AZ、db.t4g.medium
│   └── (ElastiCacheなし、コスト削減)
│
├── 06_storage/
│   ├── s3-buckets-stack.yaml
│   └── cloudfront-stack.yaml
│
├── 07_monitoring/
│   ├── cloudwatch-alarms-stack.yaml    # 最小限
│   ├── cloudwatch-logs-stack.yaml      # 保持期間30日
│   └── sns-topics-stack.yaml
│
└── 08_backup/
    ├── backup-vault-stack.yaml
    └── backup-plan-stack.yaml          # 週1回バックアップ
```

**スタック総数**: 約25スタック

---

## 3. スタック依存関係

### 3.1 依存関係グラフ

```
[01_foundation]
  organizations-stack
  scp-stack
  iam-roles-stack
       ↓
[02_network - 基盤]
  vpc-core-stack
       ↓
  subnets-stack
       ↓
  route-tables-stack
  nat-gateways-stack
  vpc-endpoints-stack
  vpc-flowlogs-stack
       ↓
  tgw-core-stack
       ↓
  tgw-attachments-stack
       ↓
  tgw-route-tables-stack
       ↓
  dx-gateway-stack
       ↓
  dx-connections-stack
       ↓
[03_security]
  sg-alb-stack
  sg-ecs-stack
  sg-rds-stack
  sg-elasticache-stack
  waf-stack
  kms-stack
  secrets-manager-stack
  cognito-stack
       ↓
[04_compute]
  ecr-stack
       ↓
  alb-stack
       ↓
  ecs-cluster-stack
       ↓
  ecs-task-definition-stack
       ↓
  ecs-service-stack
       ↓
  autoscaling-stack
       ↓
[05_data]
  rds-subnet-group-stack
  rds-parameter-group-stack
  rds-option-group-stack
       ↓
  rds-instance-stack
       ↓
  elasticache-subnet-group-stack
  elasticache-parameter-group-stack
       ↓
  elasticache-cluster-stack
       ↓
[06_storage]
  s3-buckets-stack
       ↓
  s3-lifecycle-stack
       ↓
  cloudfront-stack
       ↓
[07_monitoring]
  sns-topics-stack
       ↓
  cloudwatch-logs-stack
       ↓
  cloudwatch-alarms-stack
  cloudwatch-dashboards-stack
  cloudtrail-stack
  config-stack
       ↓
[08_backup]
  backup-vault-stack
       ↓
  backup-plan-stack
       ↓
  backup-selection-stack
       ↓
[09_dns]
  route53-stack
```

---

### 3.2 クロススタック参照（Exports/Imports）

#### 3.2.1 エクスポート例（VPC）

```yaml
# vpc-core-stack.yaml
Outputs:
  VPCId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub '${AWS::StackName}-VPCId'

  VPCCidr:
    Description: VPC CIDR Block
    Value: !GetAtt VPC.CidrBlock
    Export:
      Name: !Sub '${AWS::StackName}-VPCCidr'
```

#### 3.2.2 インポート例（サブネット）

```yaml
# subnets-stack.yaml
Parameters:
  VPCStackName:
    Type: String
    Default: niigata-kaigo-prod-vpc-core-stack

Resources:
  PublicSubnet1a:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !ImportValue
        Fn::Sub: '${VPCStackName}-VPCId'
      CidrBlock: 10.1.1.0/24
```

---

## 4. パラメータ管理

### 4.1 環境別パラメータファイル

```
cloudformation/parameters/
├── production/
│   ├── vpc-core-params.json
│   ├── ecs-service-params.json
│   └── rds-instance-params.json
│
└── staging/
    ├── vpc-core-params.json
    ├── ecs-service-params.json
    └── rds-instance-params.json
```

#### 4.1.1 パラメータファイル例

```json
// production/vpc-core-params.json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "production"
  },
  {
    "ParameterKey": "VPCCidr",
    "ParameterValue": "10.1.0.0/16"
  },
  {
    "ParameterKey": "EnableDnsSupport",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "EnableDnsHostnames",
    "ParameterValue": "true"
  }
]
```

```json
// staging/vpc-core-params.json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "staging"
  },
  {
    "ParameterKey": "VPCCidr",
    "ParameterValue": "10.2.0.0/16"
  },
  {
    "ParameterKey": "EnableDnsSupport",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "EnableDnsHostnames",
    "ParameterValue": "true"
  }
]
```

---

### 4.2 Systems Manager Parameter Store統合

**推奨**: 機密情報はParameter Storeに格納し、CloudFormationから参照

```yaml
Parameters:
  DBPassword:
    Type: AWS::SSM::Parameter::Value<String>
    Default: /niigata-kaigo/production/db/password
    NoEcho: true

Resources:
  RDSInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      MasterUserPassword: !Ref DBPassword
```

**Parameter Store登録**:
```bash
aws ssm put-parameter \
  --name /niigata-kaigo/production/db/password \
  --value "YourSecurePassword123!" \
  --type SecureString \
  --key-id alias/aws/ssm \
  --region ap-northeast-1
```

---

## 5. デプロイ戦略

### 5.1 デプロイフロー

```
1. Change Setの作成
   ↓
2. Change Setのレビュー
   ↓
3. 承認（手動）
   ↓
4. Change Setの実行
   ↓
5. ロールバック準備（エラー時）
```

### 5.2 デプロイスクリプト

```bash
#!/bin/bash
# deploy-stack.sh

ENVIRONMENT=$1  # production or staging
STACK_NAME=$2
TEMPLATE_FILE=$3
PARAMS_FILE=$4

# Change Setの作成
aws cloudformation create-change-set \
  --stack-name ${STACK_NAME} \
  --change-set-name ${STACK_NAME}-changeset-$(date +%Y%m%d%H%M%S) \
  --template-body file://${TEMPLATE_FILE} \
  --parameters file://${PARAMS_FILE} \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=Environment,Value=${ENVIRONMENT} \
         Key=Project,Value=niigata-kaigo \
  --region ap-northeast-1

echo "Change Set created. Please review before executing."
```

---

### 5.3 ロールバック戦略

**自動ロールバック設定**:
```yaml
# すべてのスタックで有効化
--on-failure ROLLBACK
```

**手動ロールバック手順**:
```bash
# スタック更新失敗時
aws cloudformation cancel-update-stack \
  --stack-name ${STACK_NAME} \
  --region ap-northeast-1

# 前のバージョンに戻す
aws cloudformation update-stack \
  --stack-name ${STACK_NAME} \
  --template-body file://previous-version.yaml \
  --parameters file://previous-params.json \
  --region ap-northeast-1
```

---

## 6. タグ戦略

### 6.1 必須タグ

すべてのリソースに以下のタグを付与：

| タグキー | タグ値例 | 用途 |
|---------|---------|------|
| Environment | Production, Staging | 環境識別 |
| Project | niigata-kaigo | プロジェクト識別 |
| ManagedBy | CloudFormation | 管理方法 |
| Owner | admin@niigata-city.jp | 責任者 |
| CostCenter | IT-Dept | コスト配分 |

### 6.2 CloudFormationテンプレート内タグ設定

```yaml
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VPCCidr
      Tags:
        - Key: Name
          Value: !Sub '${EnvironmentName}-vpc'
        - Key: Environment
          Value: !Ref EnvironmentName
        - Key: Project
          Value: niigata-kaigo
        - Key: ManagedBy
          Value: CloudFormation
        - Key: Owner
          Value: admin@niigata-city.jp
        - Key: CostCenter
          Value: IT-Dept
```

---

## 7. ベストプラクティス

### 7.1 テンプレート設計

1. **パラメータの活用**
   - 環境別の値はパラメータ化
   - デフォルト値を設定

2. **Output/Exportの活用**
   - 他スタックから参照する値はエクスポート
   - エクスポート名は一意に（スタック名をプレフィックス）

3. **DeletionPolicyの設定**
   - RDS、S3等の重要リソースは`Retain`
   - テスト環境は`Delete`

```yaml
Resources:
  RDSInstance:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Retain
    UpdateReplacePolicy: Snapshot
    Properties:
      # ...
```

4. **Conditionの活用**
   - 環境別のリソース作成制御

```yaml
Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'production']

Resources:
  ElastiCacheCluster:
    Type: AWS::ElastiCache::CacheCluster
    Condition: IsProduction  # ステージングでは作成しない
    Properties:
      # ...
```

---

### 7.2 変更管理

1. **Change Setの必須利用**
   - すべての更新でChange Setを作成
   - レビュー後に実行

2. **バージョン管理**
   - GitでCloudFormationテンプレート管理
   - タグでバージョン管理

3. **ドリフト検出**
   - 定期的にドリフト検出を実行
   - 手動変更を検出・修正

```bash
# ドリフト検出
aws cloudformation detect-stack-drift \
  --stack-name ${STACK_NAME} \
  --region ap-northeast-1

# ドリフト検出結果確認
aws cloudformation describe-stack-resource-drifts \
  --stack-name ${STACK_NAME} \
  --region ap-northeast-1
```

---

## 8. セキュリティ

### 8.1 IAMロール

**CloudFormationサービスロール**:
```yaml
CloudFormationExecutionRole:
  Type: AWS::IAM::Role
  Properties:
    RoleName: CloudFormationExecutionRole
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal:
            Service: cloudformation.amazonaws.com
          Action: sts:AssumeRole
    ManagedPolicyArns:
      - arn:aws:iam::aws:policy/PowerUserAccess
    Policies:
      - PolicyName: CloudFormationExecutionPolicy
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - iam:CreateRole
                - iam:PutRolePolicy
                - iam:AttachRolePolicy
              Resource: '*'
```

### 8.2 Secrets Manager統合

**機密情報の管理**:
```yaml
Resources:
  DBPasswordSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub '${EnvironmentName}/db/password'
      GenerateSecretString:
        SecretStringTemplate: '{"username": "admin"}'
        GenerateStringKey: 'password'
        PasswordLength: 32
        ExcludeCharacters: '"@/\'

  RDSInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      MasterUsername: !Sub '{{resolve:secretsmanager:${DBPasswordSecret}:SecretString:username}}'
      MasterUserPassword: !Sub '{{resolve:secretsmanager:${DBPasswordSecret}:SecretString:password}}'
```

---

## 9. まとめ

### 9.1 主要原則

1. **ファイル分割3原則**に基づくスタック設計
2. クロススタック参照でスタック間連携
3. パラメータファイルで環境別管理
4. Change Setで安全なデプロイ
5. タグ戦略でコスト管理・リソース追跡

### 9.2 次のステップ

1. [スタック依存関係の詳細](stack_dependencies.md)を確認
2. [ディレクトリ構造](directory_structure.md)を確認
3. 各スタックのCloudFormationテンプレート作成開始

---

**作成日**: 2025-11-05
**レビュー状態**: Draft
**参照**: [AWSベストプラクティス - CloudFormation](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/best-practices.html)
