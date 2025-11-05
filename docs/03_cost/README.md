# コスト見積もり

## 概要

本ディレクトリには、新潟市介護保険事業所システムのAWSインフラコスト見積もりを格納しています。

## ドキュメント一覧

| ドキュメント | 概要 |
|------------|------|
| [cost_estimate.md](cost_estimate.md) | コスト見積もり総括 |
| [production_cost_breakdown.md](production_cost_breakdown.md) | 本番環境コスト内訳 |
| [staging_cost_breakdown.md](staging_cost_breakdown.md) | ステージング環境コスト内訳 |
| [cost_optimization_plan.md](cost_optimization_plan.md) | コスト最適化計画 |

## 見積もり前提条件

- **価格基準日**: 2025年11月5日
- **リージョン**: 東京リージョン（ap-northeast-1）
- **為替レート**: 1 USD = 150 JPY
- **稼働時間**: 本番24時間365日、ステージング平日10時間

## 参照

- [AWS Pricing Calculator](https://calculator.aws/)
- [基本設計書](../02_design/basic/)
- [詳細設計書](../02_design/detailed/)
