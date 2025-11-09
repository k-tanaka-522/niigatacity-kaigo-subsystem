# IaC戦略（Infrastructure as Code）

## 目的
新潟市介護保険事業所システムのインフラストラクチャをコードとして管理し、再現性・可監査性・変更追跡を実現する。

## 影響範囲
- AWSリソースのプロビジョニング
- 環境間の一貫性
- インフラ変更の安全性
- コンプライアンス準拠（GCAS）

## 前提条件
- AWS CloudFormationを使用
- マルチアカウント構成（4アカウント）
- Change Setsによるdry-run必須

---

## IaCツール: AWS CloudFormation

### 採用理由

| 理由 | 説明 |
|------|------|
| **AWS ネイティブ** | AWSサービスとの完全な統合 |
| **Change Sets** | dry-run による変更プレビュー機能 |
| **ドリフト検出** | 手動変更の検出機能 |
| **コンプライアンス** | AWS Config との統合 |
| **学習コスト** | AWSドキュメントが充実 |

### 代替案の検討

| ツール | メリット | デメリット | 採用判断 |
|-------|---------|----------|---------|
| **Terraform** | マルチクラウド対応<br>豊富なプロバイダー | 追加の状態管理必要<br>AWS機能のラグ | ❌ 不採用<br>AWS専用なのでCloudFormationで十分 |
| **AWS CDK** | プログラミング言語で記述<br>再利用性高い | CloudFormationへの変換必要<br>学習コスト高い | ❌ 不採用<br>チームのスキルセットと合わない |

---

## スタック設計

### スタック分割方針

**原則**: ライフサイクルごとにスタックを分割し、変更の影響範囲を最小化する。

| スタック名 | 内容 | 更新頻度 | 依存関係 |
|----------|------|---------|---------|
| `niigata-kaigo-prod-network` | VPC, サブネット, Transit Gateway | 低（月1回未満） | なし |
| `niigata-kaigo-prod-security` | Security Groups, NACLs, WAF | 低（月1回程度） | Network |
| `niigata-kaigo-prod-database` | RDS MySQL, ElastiCache | 低（月1回程度） | Network, Security |
| `niigata-kaigo-prod-compute` | ECS Fargate, ALB, Auto Scaling | 中（週1回程度） | Network, Security |
| `niigata-kaigo-prod-cognito` | Cognito User Pool, Identity Pool | 低（月1回未満） | Security |
| `niigata-kaigo-prod-storage` | S3, CloudFront | 低（月1回程度） | Security |
| `niigata-kaigo-prod-monitoring` | CloudWatch, SNS, アラーム | 中（週1回程度） | すべて |

### スタック依存関係の管理

**方法**: クロススタック参照（Outputs / Fn::ImportValue）

```yaml
# niigata-kaigo-prod-network スタック
Outputs:
  VPCId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub ${AWS::StackName}-VPCId

  PrivateSubnet1Id:
    Description: Private Subnet 1 ID
    Value: !Ref PrivateSubnet1
    Export:
      Name: !Sub ${AWS::StackName}-PrivateSubnet1Id

# niigata-kaigo-prod-compute スタック（参照側）
Resources:
  ECSService:
    Type: AWS::ECS::Service
    Properties:
      NetworkConfiguration:
        AwsvpcConfiguration:
          Subnets:
            - Fn::ImportValue: niigata-kaigo-prod-network-PrivateSubnet1Id
            - Fn::ImportValue: niigata-kaigo-prod-network-PrivateSubnet2Id
```

---

## Change Sets による安全なデプロイ

### Change Sets 必須化

**原則**: 本番環境への変更は必ず Change Sets で差分確認後に実行する。

```bash
# ❌ 悪い例: 直接デプロイ（本番環境で禁止）
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name niigata-kaigo-prod-network

# ✅ 良い例: Change Sets 経由（本番環境で必須）
# 1. Change Set 作成
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-prod-network \
  --change-set-name update-2025-11-07 \
  --template-body file://template.yaml \
  --parameters file://parameters-prod.json

# 2. Change Set の内容確認（dry-run）
aws cloudformation describe-change-set \
  --stack-name niigata-kaigo-prod-network \
  --change-set-name update-2025-11-07

# 3. レビュー・承認

# 4. Change Set 実行
aws cloudformation execute-change-set \
  --stack-name niigata-kaigo-prod-network \
  --change-set-name update-2025-11-07

# 5. 実行状況の監視
aws cloudformation describe-stack-events \
  --stack-name niigata-kaigo-prod-network
```

### Change Sets で確認すべき項目

| 項目 | 確認ポイント |
|------|------------|
| **Action** | Add / Modify / Remove のいずれか |
| **Replacement** | True（リソース再作成）の場合は影響を確認 |
| **ResourceType** | 変更対象のAWSサービス |
| **LogicalResourceId** | CloudFormation上のリソース名 |
| **PhysicalResourceId** | 実際のAWSリソースID |

**特に注意すべき変更**:
- `Replacement: True` - リソースが再作成される（データ消失の可能性）
- `Remove` - リソースが削除される
- データベース・ストレージの変更

---

## パラメータ管理

### 環境差分の管理

**原則**: テンプレートは1つ、パラメータファイルで環境を切り替える。

```
infra/cloudformation/
├── templates/
│   ├── network.yaml          # テンプレート（共通）
│   ├── security.yaml
│   ├── database.yaml
│   └── compute.yaml
└── parameters/
    ├── prod/
    │   ├── network.json      # 本番パラメータ
    │   ├── security.json
    │   ├── database.json
    │   └── compute.json
    └── staging/
        ├── network.json      # ステージングパラメータ
        ├── security.json
        ├── database.json
        └── compute.json
```

### パラメータファイルの例

```json
// parameters/prod/database.json
[
  {
    "ParameterKey": "DBInstanceClass",
    "ParameterValue": "db.r6g.xlarge"
  },
  {
    "ParameterKey": "DBAllocatedStorage",
    "ParameterValue": "500"
  },
  {
    "ParameterKey": "MultiAZ",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "BackupRetentionPeriod",
    "ParameterValue": "7"
  }
]
```

```json
// parameters/staging/database.json
[
  {
    "ParameterKey": "DBInstanceClass",
    "ParameterValue": "db.t4g.medium"
  },
  {
    "ParameterKey": "DBAllocatedStorage",
    "ParameterValue": "100"
  },
  {
    "ParameterKey": "MultiAZ",
    "ParameterValue": "false"
  },
  {
    "ParameterKey": "BackupRetentionPeriod",
    "ParameterValue": "1"
  }
]
```

---

## シークレット管理

### 原則: ハードコード禁止

**禁止事項**:
- パスワード・APIキーをテンプレートに直接記載
- パラメータファイルにシークレットを記載
- Gitリポジトリにシークレットをコミット

### 推奨方法: AWS Systems Manager Parameter Store

```yaml
# CloudFormationテンプレート
Parameters:
  DBPasswordParameterName:
    Type: String
    Default: /niigata-kaigo/prod/db/master-password
    Description: Parameter Store path for DB password

Resources:
  DBInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      MasterUsername: admin
      MasterUserPassword: !Sub '{{resolve:ssm-secure:${DBPasswordParameterName}}}'
      # その他のプロパティ
```

```bash
# パスワードの事前登録（初回のみ）
aws ssm put-parameter \
  --name /niigata-kaigo/prod/db/master-password \
  --type SecureString \
  --value "MySecurePassword123!" \
  --description "RDS master password"

# CloudFormationはParameter Storeから自動取得
```

### シークレットのローテーション

| シークレット | ローテーション頻度 | 方法 |
|------------|-----------------|------|
| DBパスワード | 90日ごと | AWS Secrets Manager（自動ローテーション） |
| APIキー | 180日ごと | 手動ローテーション |
| 暗号化キー（KMS） | 365日ごと | AWS KMS（自動ローテーション） |

---

## ドリフト検出

### 目的
手動でAWSコンソールから変更されたリソースを検出し、IaCとの乖離を防ぐ。

### 定期実行（週次）

```bash
# スタックのドリフト検出を開始
aws cloudformation detect-stack-drift \
  --stack-name niigata-kaigo-prod-network

# 検出IDを取得
DRIFT_ID=$(aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id <detection-id> \
  --query 'StackDriftDetectionId' \
  --output text)

# 検出結果の確認
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id $DRIFT_ID

# ドリフトしたリソースの詳細
aws cloudformation describe-stack-resource-drifts \
  --stack-name niigata-kaigo-prod-network
```

### ドリフト検出時の対応

| ドリフトステータス | 対応 |
|------------------|------|
| **IN_SYNC** | 問題なし |
| **MODIFIED** | 手動変更を検出<br>→ CloudFormationテンプレートを修正して再デプロイ |
| **DELETED** | リソースが削除されている<br>→ スタック再作成またはリソース復旧 |
| **NOT_CHECKED** | ドリフト検出未対応のリソース |

---

## 命名規則

### スタック名

```
{project}-{env}-{service}
```

**例**:
- `niigata-kaigo-prod-network`
- `niigata-kaigo-prod-database`
- `niigata-kaigo-staging-compute`

### リソース名（LogicalId）

```yaml
# ✅ 良い例: パスカルケース、用途が明確
Resources:
  VPC:
    Type: AWS::EC2::VPC

  PrivateSubnet1:
    Type: AWS::EC2::Subnet

  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer

# ❌ 悪い例: 略称、意味不明
Resources:
  vpc1:
    Type: AWS::EC2::VPC

  sub1:
    Type: AWS::EC2::Subnet

  alb:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
```

### 物理リソース名（タグ）

```yaml
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      Tags:
        - Key: Name
          Value: !Sub ${AWS::StackName}-vpc
        - Key: Project
          Value: niigata-kaigo
        - Key: Environment
          Value: production
        - Key: ManagedBy
          Value: CloudFormation
```

---

## ロールバック戦略

### 自動ロールバック

CloudFormationのデフォルト動作:
- スタック作成失敗時 → 自動削除
- スタック更新失敗時 → 自動ロールバック（前の状態に戻る）

### 手動ロールバック

```bash
# Change Set の実行を取り消す（実行前のみ）
aws cloudformation delete-change-set \
  --stack-name niigata-kaigo-prod-network \
  --change-set-name update-2025-11-07

# スタック更新の取り消し（特定バージョンに戻す）
# → 前のテンプレート・パラメータで Change Set を作成して実行
```

### ロールバック不可能な変更

以下の変更はロールバックできない（リソース再作成が必要）:
- RDSインスタンスの削除
- S3バケットの削除（データ消失）
- KMSキーの削除

**対策**: 削除保護（DeletionPolicy: Retain）を設定

```yaml
Resources:
  DBInstance:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Retain  # スタック削除時もリソースを保持
    Properties:
      # ...

  S3Bucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain
    Properties:
      # ...
```

---

## セキュリティベストプラクティス

### 1. 最小権限の原則

```yaml
# CloudFormationサービスロールに最小限の権限を付与
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "ecs:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ap-northeast-1"
        }
      }
    }
  ]
}
```

### 2. 暗号化の徹底

```yaml
# RDS: 保管時暗号化
Resources:
  DBInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      StorageEncrypted: true
      KmsKeyId: !Ref DBEncryptionKey

# S3: デフォルト暗号化
  S3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: aws:kms
              KMSMasterKeyID: !Ref S3EncryptionKey
```

### 3. パブリックアクセスの禁止

```yaml
# S3: パブリックアクセス完全ブロック
Resources:
  S3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
```

---

## バージョン管理

### テンプレートのバージョン管理

```yaml
# テンプレートにメタデータを追加
AWSTemplateFormatVersion: '2010-09-09'
Description: 'niigata-kaigo network stack - v1.2.0'

Metadata:
  Version: 1.2.0
  LastUpdated: 2025-11-07
  Author: CloudFormation Team
  ChangeLog:
    - 1.2.0: Add Transit Gateway
    - 1.1.0: Add private subnets
    - 1.0.0: Initial release
```

### Gitタグとの連携

```bash
# テンプレート変更をコミット
git add infra/cloudformation/templates/network.yaml
git commit -m "infra: add Transit Gateway to network stack"

# バージョンタグを作成
git tag -a infra-network-v1.2.0 -m "Network stack version 1.2.0"
git push origin infra-network-v1.2.0
```

---

## テスト戦略

### 1. 構文チェック（cfn-lint）

```bash
# インストール
pip install cfn-lint

# 実行
cfn-lint infra/cloudformation/templates/*.yaml
```

### 2. スタック検証（AWS CLI）

```bash
# テンプレートの検証
aws cloudformation validate-template \
  --template-body file://network.yaml
```

### 3. ステージング環境での事前テスト

```
1. ステージング環境で Change Set 作成
2. Change Set の差分確認
3. ステージング環境へデプロイ
4. 動作確認
5. 問題なければ本番環境へ展開
```

---

## 運用フロー

### 日常的な変更（例: ECSタスク定義更新）

```bash
# 1. テンプレート編集
vi infra/cloudformation/templates/compute.yaml

# 2. 構文チェック
cfn-lint infra/cloudformation/templates/compute.yaml

# 3. ステージング環境へデプロイ
./scripts/deploy-staging.sh compute

# 4. 動作確認

# 5. 本番環境へ Change Set 作成
./scripts/create-changeset-prod.sh compute

# 6. Change Set レビュー

# 7. 本番環境へデプロイ
./scripts/execute-changeset-prod.sh compute
```

---

## トラブルシューティング

### スタック更新が ROLLBACK_IN_PROGRESS になった

**原因**: リソース作成・更新に失敗

**対処**:
1. CloudWatch Logs でエラーを確認
2. 失敗したリソースを特定
3. テンプレート・パラメータを修正
4. 再度 Change Set を作成して実行

### スタックが UPDATE_ROLLBACK_COMPLETE で止まった

**原因**: ロールバック後、手動介入が必要

**対処**:
```bash
# スタックを安定状態に戻す
aws cloudformation continue-update-rollback \
  --stack-name niigata-kaigo-prod-network
```

### Change Set の実行がスキップされた

**原因**: 変更内容がない

**対処**:
- 問題なし（変更がなかったことを確認）

---

## 参照

- `.claude/docs/40_standards/45_cloudformation.md` - CloudFormation標準
- `docs/02_設計/基本設計/10_CICD/ブランチ戦略.md` - ブランチ戦略
- `docs/02_設計/基本設計/10_CICD/GitHub_Actions設計.md` - CI/CD設計
- [AWS CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)

---

**作成日**: 2025-11-07
**作成者**: Claude (architect サブエージェント)
**レビュー状態**: Draft
