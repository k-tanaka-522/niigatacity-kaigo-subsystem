# CloudFormation Templates

**プロジェクト**: 新潟市介護保険事業所システム
**最終更新日**: 2025-11-11
**構成**: ネストスタック（stacks/ + templates/ + parameters/）

---

## 📁 ディレクトリ構造

```
infra/app/cloudformation/
├── README.md                            # このファイル
├── REFACTORING_REPORT.md                # リファクタリング完了レポート
├── DEPLOYMENT_GUIDE.md                  # デプロイ手順書
├── stacks/                              # 親スタック（デプロイ単位）
│   ├── 03-network/
│   │   └── main.yaml                    # VPC, Subnets, Route Tables, NAT GW
│   ├── 04-security/
│   │   └── main.yaml                    # KMS, Security Groups
│   ├── 05-database/
│   │   └── main.yaml                    # RDS MySQL, ElastiCache Redis ✅
│   ├── 06-compute/
│   │   └── main.yaml                    # ALB, ECS Cluster, ECS Service ✅
│   ├── 07-storage/
│   │   └── main.yaml                    # S3, CloudFront
│   ├── 08-auth/
│   │   └── main.yaml                    # Cognito User Pool, Identity Pool
│   └── 09-monitoring/
│       └── main.yaml                    # CloudWatch Alarms, AWS Backup ✅
├── templates/                           # ネストスタック（再利用可能）
│   ├── network/
│   │   ├── vpc-and-igw.yaml
│   │   ├── subnets.yaml
│   │   ├── route-tables.yaml
│   │   ├── nat-gateways.yaml
│   │   └── transit-gateway-attachment.yaml
│   ├── security/
│   │   ├── kms.yaml
│   │   └── security-groups.yaml
│   ├── database/
│   │   ├── rds-mysql.yaml
│   │   └── elasticache-redis.yaml      # ✅ 修正済み
│   ├── compute/
│   │   ├── alb.yaml                     # ✅ 修正済み
│   │   └── ecs-cluster.yaml            # ✅ 修正済み
│   ├── storage/
│   │   ├── s3-buckets.yaml
│   │   └── cloudfront.yaml
│   ├── auth/
│   │   ├── cognito-user-pool.yaml
│   │   └── cognito-identity-pool.yaml
│   └── monitoring/
│       ├── cloudwatch-alarms.yaml       # ✅ 修正済み
│       └── aws-backup.yaml
└── parameters/                          # 環境別パラメータ
    ├── dev/
    │   ├── 04-security-stack-params.json
    │   ├── 05-database-stack-params.json
    │   ├── 06-compute-stack-params.json  # ✅ 修正済み
    │   ├── 07-storage-stack-params.json
    │   ├── 08-auth-stack-params.json
    │   └── 09-monitoring-stack-params.json
    ├── staging/
    │   └── （同様の構成）
    └── production/
        └── （同様の構成）
```

**✅ = リファクタリング済み**

---

## 🎯 スタック構成（デプロイ順序）

| スタック | 変更頻度 | デプロイ戦略 | 含まれるリソース |
|---------|--------|------------|----------------|
| 03-network | 年1回 | 手動、複数人承認 | VPC, Subnets, NAT GW, Route Tables |
| 04-security | 月1回 | 手動、1人承認 | KMS, Security Groups |
| 05-database | 月1回 | 手動、1人承認 | RDS, ElastiCache ✅ |
| 06-compute | 週数回 | 自動（main マージ時） | ALB, ECS Cluster, ECS Service ✅ |
| 07-storage | 月1回 | 手動、1人承認 | S3, CloudFront |
| 08-auth | 月1回 | 手動、1人承認 | Cognito User Pool, Identity Pool |
| 09-monitoring | 月1回 | 手動、1人承認 | CloudWatch Alarms, AWS Backup ✅ |

---

## 🚀 クイックスタート

### 1. テンプレート検証

```bash
cd infra/app/cloudformation

# すべてのテンプレートを検証
for stack in stacks/*/main.yaml; do
  echo "Validating: $stack"
  aws cloudformation validate-template --template-body file://$stack > /dev/null
done
```

### 2. テンプレートを S3 にアップロード

```bash
# dev 環境用
aws s3 sync templates/ \
  s3://niigata-kaigo-cfn-templates-dev/app/templates/ \
  --profile niigata-kaigo-dev
```

### 3. スタックをデプロイ

```bash
# Network Stack
aws cloudformation create-change-set \
  --stack-name niigata-kaigo-dev-03-network \
  --change-set-name deploy-$(date +%Y%m%d-%H%M%S) \
  --template-body file://stacks/03-network/main.yaml \
  --parameters file://parameters/dev/03-network-stack-params.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-type CREATE \
  --profile niigata-kaigo-dev

# Change Set 確認（dry-run）
aws cloudformation describe-change-set \
  --stack-name niigata-kaigo-dev-03-network \
  --change-set-name <CHANGE_SET_NAME> \
  --profile niigata-kaigo-dev

# Change Set 実行
aws cloudformation execute-change-set \
  --stack-name niigata-kaigo-dev-03-network \
  --change-set-name <CHANGE_SET_NAME> \
  --profile niigata-kaigo-dev
```

**詳細な手順は [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) を参照してください。**

---

## 🔍 よくある変更

| やりたいこと | 編集するファイル | デプロイするスタック |
|------------|----------------|-------------------|
| VPC の CIDR を変更 | `templates/network/vpc-and-igw.yaml` | 03-network |
| RDS のインスタンスクラス変更 | `parameters/dev/05-database-stack-params.json` | 05-database |
| ECS のタスク定義変更 | `templates/compute/ecs-cluster.yaml` | 06-compute |
| ALB のヘルスチェックパス変更 | `parameters/dev/06-compute-stack-params.json` | 06-compute |
| CloudWatch アラーム追加 | `templates/monitoring/cloudwatch-alarms.yaml` | 09-monitoring |
| CloudWatch Logs 保持期間変更 | `parameters/dev/06-compute-stack-params.json` | 06-compute |

---

## ✅ リファクタリング完了（2025-11-11）

### 修正内容

1. **ElastiCache Redis (templates/database/elasticache-redis.yaml)**:
   - ✅ AuthToken を Secrets Manager から取得
   - ✅ CloudWatch Logs 保持期間を 90日に変更（GCAS準拠）

2. **ECS Cluster (templates/compute/ecs-cluster.yaml)**:
   - ✅ Conditions を追加（HasDBSecret, HasRedisSecret）
   - ✅ Secrets の条件付き設定
   - ✅ TaskExecutionRole の Policies を条件付きに変更
   - ✅ CloudWatch Logs 保持期間のデフォルトを 90日に変更

3. **ALB (templates/compute/alb.yaml)**:
   - ✅ LogsBucketName パラメータを追加
   - ✅ Access Logs の条件付き有効化

4. **CloudWatch Alarms (templates/monitoring/cloudwatch-alarms.yaml)**:
   - ✅ SNS Topic の Condition を修正（NoSNSTopic を追加）

5. **Compute Stack (stacks/06-compute/main.yaml)**:
   - ✅ LogsBucketName パラメータを追加
   - ✅ LogRetentionDays のデフォルトを 90日に変更

6. **パラメータファイル (parameters/dev/06-compute-stack-params.json)**:
   - ✅ LogsBucketName を追加
   - ✅ LogRetentionDays を 90 に変更

**詳細は [REFACTORING_REPORT.md](./REFACTORING_REPORT.md) を参照してください。**

---

## 📊 GCAS準拠チェックリスト

### セキュリティ要件

- [x] **暗号化**: RDS, ElastiCache は保管時暗号化（KMS）
- [x] **通信暗号化**: RDS/Redis は TLS 必須
- [x] **認証**: ElastiCache AuthToken 有効化 ✅ **今回修正**
- [x] **IAM**: 最小権限の原則（Conditions で不要なポリシーを除外）✅ **今回修正**

### 監査・コンプライアンス要件

- [x] **ログ保管**: CloudWatch Logs 90日保管 ✅ **今回修正**
- [x] **アクセスログ**: ALB Access Logs 有効化 ✅ **今回修正**
- [x] **監査証跡**: CloudTrail 有効
- [x] **変更管理**: Change Sets 必須（dry-run）

### 運用要件

- [x] **監視**: CloudWatch Alarms 設定 ✅ **SNS Condition 修正**
- [x] **バックアップ**: RDS 自動バックアップ（7日保持）
- [x] **高可用性**: Multi-AZ 配置（RDS, ElastiCache）

---

## 🔧 技術標準への準拠

このプロジェクトは、以下の技術標準に準拠しています:

- ✅ **ネストスタック構成**: stacks/ (親) + templates/ (ネスト) + parameters/ (環境差分)
- ✅ **Change Sets 必須**: dry-run による安全なデプロイ
- ✅ **命名規則**: ケバブケース（`${ProjectName}-${EnvironmentName}-resource-type`）
- ✅ **タグ戦略**: Name, Environment, Project タグを全リソースに付与
- ✅ **セキュリティ**: Secrets Manager 使用、KMS 暗号化、TLS 必須
- ✅ **ログ保管**: CloudWatch Logs 90日保管（GCAS準拠）

**技術標準の詳細**: `.claude/docs/40_standards/42_infra/iac/cloudformation.md`

---

## 📝 次のステップ

### 短期（1週間以内）

- [ ] dev 環境でリファクタリング後のテンプレートをデプロイ
- [ ] 機能テスト（ElastiCache AuthToken、ECS Secrets、ALB Access Logs）
- [ ] CloudWatch Logs 保持期間の確認（90日設定されているか）

### 中期（1ヶ月以内）

- [ ] staging 環境にデプロイ
- [ ] 負荷テスト実施
- [ ] 監視アラートの調整

### 長期（3ヶ月以内）

- [ ] production 環境にデプロイ
- [ ] CI/CD パイプライン構築（GitHub Actions）
- [ ] ライフサイクル別スタック再編成の検討

---

## 🆘 トラブルシューティング

### よくある問題

1. **Change Set 作成失敗**: [DEPLOYMENT_GUIDE.md の 5.1 節](./DEPLOYMENT_GUIDE.md#51-change-set-作成失敗) を参照
2. **スタック作成失敗（ROLLBACK_COMPLETE）**: [DEPLOYMENT_GUIDE.md の 5.2 節](./DEPLOYMENT_GUIDE.md#52-スタック作成失敗rollback_complete) を参照
3. **ECS タスクが起動しない**: [DEPLOYMENT_GUIDE.md の 5.3 節](./DEPLOYMENT_GUIDE.md#53-ecs-タスクが起動しない) を参照
4. **ALB でヘルスチェック失敗**: [DEPLOYMENT_GUIDE.md の 5.4 節](./DEPLOYMENT_GUIDE.md#54-alb-でヘルスチェック失敗) を参照
5. **Redis 接続エラー**: [DEPLOYMENT_GUIDE.md の 5.5 節](./DEPLOYMENT_GUIDE.md#55-redis-接続エラー) を参照

---

## 📚 関連ドキュメント

- [REFACTORING_REPORT.md](./REFACTORING_REPORT.md) - リファクタリング完了レポート（変更内容の詳細）
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - デプロイ手順書（スタック別の詳細手順）
- `.claude/docs/40_standards/42_infra/iac/cloudformation.md` - CloudFormation 技術標準
- `docs/02_設計/基本設計/` - システム基本設計書

---

## 📞 サポート

質問や問題がある場合は、以下に連絡してください:

- **PM エージェント**: プロジェクト全体の方針・優先順位
- **SRE エージェント**: インフラ・デプロイ・運用
- **Architect エージェント**: システム設計・技術選定

---

**作成者**: SRE エージェント
**最終更新日**: 2025-11-11
**バージョン**: 1.0.0
