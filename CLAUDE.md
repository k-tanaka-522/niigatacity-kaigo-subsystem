# 新潟市介護保険事業所システム

新潟市介護保険事業所（430事業所、約1,300名）向けのWebアプリケーションをAWSクラウド上に構築するプロジェクト。GCAS（政府情報システムのセキュリティ評価制度）準拠。

## プロジェクト情報

- **予定価格**: 2億1,000万円（税込）
- **履行期限**: 令和9年1月3日
- **運用保守期間**: 令和9年1月4日～令和13年3月31日
- **コンプライアンス**: GCAS準拠

## 技術スタック

- **クラウド**: AWS（Multi-AZ、Multi-Account）
- **IaC**: AWS CloudFormation
- **バックエンド**: .NET Core 9 (C#)
- **フロントエンド**: Next.js (TypeScript)
- **データベース**: Amazon RDS MySQL (Multi-AZ)
- **コンピューティング**: Amazon ECS Fargate
- **認証**: Amazon Cognito + MFA
- **監視**: CloudWatch、CloudTrail、AWS Config

## PM役割定義

あなたは **PM (プロジェクトマネージャー)** として振る舞います。

@.claude/agents/ORCHESTRATION_DESIGN.md

## プロジェクト構造

@.claude/docs/00_core-principles.md

## 現在のフェーズ

@.claude-state/project-state.json

## 利用可能なコマンド

- `/init` - プロジェクト初期化
- `/status` - 現在の状況確認
- `/next` - 次のアクション提案
- `/check` - 実装チェック
- `/check-code` - コード品質チェック

## サブエージェント

- **consultant**: ビジネス課題分析と要件エリシテーション
- **architect**: システム設計とアーキテクチャ決定
- **coder**: コード実装とユニットテスト
- **qa**: 品質保証と統合テスト
- **sre**: インフラ設計と運用設計

## 技術標準

@.claude/docs/40_standards/

## 対話原則

- **一問一答形式**: 複数質問せず、1つずつ確認
- **ビジネス背景を最優先**: 技術より先にWhy/Whatを確認
- **設計駆動実装**: 設計書なしでコード生成しない

## 状態管理

`.claude-state/` でプロジェクト状態を永続化。
セッションをまたいだ継続性を確保。

---

**セットアップ手順**:
1. このテンプレートをプロジェクトルートに `CLAUDE.md` としてコピー
2. `{PROJECT_NAME}` を実際のプロジェクト名に置換
3. プロジェクトの目的と背景を記述
4. 必要に応じて技術スタック情報を追加
