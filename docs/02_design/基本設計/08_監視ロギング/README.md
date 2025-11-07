# 08. 監視設計

## 概要

新潟市介護保険サブシステムの監視・アラート設計ドキュメントです。

## ドキュメント構成

| ドキュメント | 概要 | ページ数 |
|------------|------|---------|
| [monitoring_design.md](./monitoring_design.md) | 監視設計全体 | 15ページ |
| [cloudwatch_alarms.md](./cloudwatch_alarms.md) | CloudWatchアラーム詳細 | 12ページ |
| [monitoring_flow.md](./monitoring_flow.md) | 監視・インシデント対応フロー | 10ページ |

## 主要な設計判断

### 監視方針

- **可用性監視**: ALB ヘルスチェック、ECS タスク監視
- **性能監視**: レスポンスタイム、スループット
- **リソース監視**: CPU、メモリ、ストレージ使用率
- **ログ監視**: エラーログ、アクセスログ
- **セキュリティ監視**: WAF、VPC Flow Logs、GuardDuty

### アラート設計

| 重要度 | 対応時間 | 通知先 |
|--------|---------|--------|
| Critical | 15分以内 | Email + Slack + 電話 |
| Warning | 1時間以内 | Email + Slack |
| Info | 翌営業日 | Email |

### 監視ツール

- **CloudWatch**: メトリクス、ログ、アラーム
- **X-Ray**: 分散トレーシング
- **Container Insights**: ECS コンテナ監視
- **GuardDuty**: セキュリティ脅威検出
- **Security Hub**: セキュリティ標準準拠

## 主要メトリクス

### ALB

- TargetResponseTime (1秒 > Warning, 3秒 > Critical)
- HTTPCode_Target_5XX_Count (10/5分 > Warning)
- UnHealthyHostCount (>= 1 > Critical)

### ECS

- CPUUtilization (75% > Warning, 90% > Critical)
- MemoryUtilization (75% > Warning, 90% > Critical)
- RunningTaskCount (< 2 > Critical)

### RDS

- CPUUtilization (75% > Warning, 90% > Critical)
- FreeableMemory (< 1GB > Warning)
- DatabaseConnections (> 80 > Warning)

## 定期監視タスク

| タスク | 頻度 | 担当 |
|-------|------|------|
| ダッシュボード確認 | 毎日 | 運用担当者 |
| 週次レポート作成 | 毎週 | 運用管理者 |
| 月次レポート作成 | 毎月 | システム管理者 |

## 関連ドキュメント

- [セキュリティ設計](../07_security/security_design.md)
- [バックアップ設計](../09_backup_dr/backup_dr_design.md)
- [コンピュート設計](../04_compute/compute_design.md)

---

**作成日**: 2025-11-05
**作成者**: Architect
