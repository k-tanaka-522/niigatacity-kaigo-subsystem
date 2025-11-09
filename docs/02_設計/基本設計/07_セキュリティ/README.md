# 07. セキュリティ設計

## 概要

新潟市介護保険サブシステムのセキュリティ設計ドキュメントです。

## ドキュメント構成

| ドキュメント | 概要 | ページ数 |
|------------|------|---------|
| [security_design.md](./security_design.md) | セキュリティ設計全体 | 20ページ |
| [security_group_rules.md](./security_group_rules.md) | セキュリティグループルール詳細 | 10ページ |
| [iam_policy_examples.json](./iam_policy_examples.json) | IAMポリシー例 | - |
| [waf_rules.json](./waf_rules.json) | WAFルール定義 | - |

## 主要な設計判断

### 多層防御戦略

1. **ネットワーク層**: Security Group、NACL
2. **アプリケーション層**: WAF、ALB
3. **データ層**: KMS暗号化、RDS暗号化
4. **認証・認可層**: IAM、Cognito
5. **監査層**: CloudTrail、Config

### セキュリティグループ設計原則

- 最小権限の原則
- デフォルト拒否
- セキュリティグループIDによる参照
- 環境分離

### IAM設計

| ロール | 用途 |
|-------|------|
| ECS Task Execution Role | ECSタスクの起動・停止 |
| ECS Task Role | アプリケーションの実行 |
| Lambda Execution Role | バックアップ処理 |
| VPC Flow Logs Role | ログ送信 |

### WAF設計

- **マネージドルール**: OWASP Top 10対策
- **カスタムルール**:
  - レート制限 (2000リクエスト/5分)
  - 地理的制限 (日本のみ)
  - IPホワイトリスト

### 暗号化設計

| リソース | 暗号化方式 | 鍵管理 |
|---------|-----------|--------|
| RDS | AES-256 | KMS (CMK) |
| ElastiCache | AES-256 | KMS (CMK) |
| S3 | SSE-KMS | KMS (CMK) |
| EFS | AES-256 | KMS (CMK) |

## セキュリティ監視

- **GuardDuty**: 脅威検出
- **Security Hub**: セキュリティ標準準拠
- **CloudWatch Alarms**: セキュリティイベント通知

## コンプライアンス

- 個人情報保護法
- マイナンバー法
- 地方公共団体の情報セキュリティポリシー

## 関連ドキュメント

- [ネットワーク設計](../03_network/network_design.md)
- [監視設計](../08_monitoring/monitoring_design.md)
- [バックアップ設計](../09_backup_dr/backup_dr_design.md)

---

**作成日**: 2025-11-05
**作成者**: Architect
