# インフラ設計

新潟市介護保険事業所システムのインフラ設計ドキュメントです。

## 📁 ディレクトリ構成

```
10_インフラ/
├── 01_ネットワーク/              # VPC、Transit Gateway、Direct Connect
├── 02_セキュリティ/              # セキュリティグループ、WAF、KMS
├── 03_監視ロギング/              # CloudWatch、CloudTrail、AWS Config
├── 04_バックアップDR/            # AWS Backup、災害復旧
├── 10_CloudFormation構成/        # IaCテンプレート構成
└── 20_CICD/                      # インフラCI/CD設計
```

## 📖 ドキュメント一覧

### 01_ネットワーク

- [ネットワーク設計.md](01_ネットワーク/03_ネットワーク/ネットワーク設計.md) - VPC、サブネット、ルーティング設計
- [VPCパラメータ.md](01_ネットワーク/03_ネットワーク/VPCパラメータ.md) - VPCパラメーター詳細
- [TransitGatewayパラメータ.md](01_ネットワーク/03_ネットワーク/TransitGatewayパラメータ.md) - Transit Gatewayパラメーター詳細

### 02_セキュリティ

- [セキュリティ設計.md](02_セキュリティ/07_セキュリティ/セキュリティ設計.md) - セキュリティ全体方針
- [セキュリティグループルール.md](02_セキュリティ/07_セキュリティ/セキュリティグループルール.md) - セキュリティグループ詳細

### 03_監視ロギング

- [監視設計.md](03_監視ロギング/08_監視ロギング/監視設計.md) - CloudWatch、CloudTrail設計
- [CloudWatchアラーム.md](03_監視ロギング/08_監視ロギング/CloudWatchアラーム.md) - アラーム設定詳細

### 04_バックアップDR

- [バックアップDR設計.md](04_バックアップDR/09_バックアップDR/バックアップDR設計.md) - バックアップ・災害復旧方針
- [backup_flow.md](04_バックアップDR/09_バックアップDR/backup_flow.md) - バックアップフロー
- [dr_procedure.md](04_バックアップDR/09_バックアップDR/dr_procedure.md) - DR手順

### 10_CloudFormation構成

- [cloudformation_structure.md](10_CloudFormation構成/10_CloudFormation構成/cloudformation_structure.md) - ファイル分割3原則とディレクトリ構造
- [deployment_strategy.md](10_CloudFormation構成/10_CloudFormation構成/deployment_strategy.md) - Change Setsを使った安全なデプロイ手順
- [stack_lifecycle.md](10_CloudFormation構成/10_CloudFormation構成/stack_lifecycle.md) - スタックのライフサイクル管理

### 20_CICD

- [IaC戦略.md](20_CICD/10_CICD/IaC戦略.md) - Infrastructure as Code戦略
- [GitHub_Actions設計.md](20_CICD/10_CICD/GitHub_Actions設計.md) - GitHub Actions CI/CD設計
- [ブランチ戦略.md](20_CICD/10_CICD/ブランチ戦略.md) - Gitブランチ戦略
- [CICDパイプライン図.drawio](20_CICD/10_CICD/CICDパイプライン図.drawio) - CI/CDパイプライン図

## 🔗 関連セクション

- [00_全体](../00_全体/README.md) - 全体設計
- [20_アプリケーション](../20_アプリケーション/README.md) - アプリケーション設計（アプリチーム担当）

## 👥 レビュアー

**インフラチーム (@infra-team)**

インフラ設計の変更は、インフラチームのレビューが必要です。

## 🔧 インフラコード

実際のCloudFormationテンプレートは以下にあります:
- [infra/cloudformation/](../../../../infra/cloudformation/)

## 📝 変更履歴

変更履歴はGitコミットログを参照してください。
