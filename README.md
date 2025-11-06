# 新潟市介護保険事業所システム - インフラストラクチャ

## 概要

本リポジトリは、新潟市介護保険事業所システムのAWSインフラストラクチャをコードとして管理するためのものです。

## プロジェクト情報

- **プロジェクト名**: 新潟市介護保険事業所システム導入業務
- **予定価格**: 2億1,000万円（税込）
- **履行期限**: 令和9年1月3日
- **運用保守期間**: 令和9年1月4日～令和13年3月31日

## 技術スタック

- **クラウドプラットフォーム**: AWS（GCAS準拠）
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **コンテナオーケストレーション**: Amazon ECS（Fargate）
- **データベース**: Amazon RDS（PostgreSQL）
- **ネットワーク**: AWS Direct Connect、VPC
- **監視**: Amazon CloudWatch、AWS X-Ray
- **AI/ML**: Amazon Bedrock（運用自動化）

## 画面イメージ

### ログイン画面
![ログイン画面](test/スクリーンショット%202025-11-07%20074708.png)

### ダッシュボード
![ダッシュボード](test/スクリーンショット%202025-11-07%20084037.png)

### 申請一覧
![申請一覧](test/スクリーンショット%202025-11-07%20084050.png)

### 事業所管理
![事業所管理](test/スクリーンショット%202025-11-07%20084058.png)

### ドキュメント管理
![ドキュメント管理](test/スクリーンショット%202025-11-07%20084118.png)

## 機能

### 実装済み機能

- ✅ ユーザー認証（ログイン）
- ✅ ダッシュボード（申請統計表示）
- ✅ 申請管理
  - 申請一覧・検索
  - 申請詳細表示
  - 新規申請作成
  - 申請編集
- ✅ 事業所管理
  - 事業所一覧・検索
  - 事業所詳細表示
  - 事業所情報編集
- ✅ ドキュメント管理
  - マニュアル・通知文書・申請様式の閲覧

### 開発中の機能

- 🚧 バックエンドAPI統合
- 🚧 認証フロー（MFA対応）
- 🚧 ファイルアップロード
- 🚧 通知機能

## アーキテクチャ

### マルチアカウント構成

- **共通系アカウント**: ネットワーク、セキュリティ、監査ログ
- **アプリケーション系アカウント（本番）**: 本番アプリケーション
- **アプリケーション系アカウント（ステージング）**: ステージング環境（T系コンピューティング利用）
- **運用系アカウント**: 監視、ログ集約、バックアップ

### 環境

- **本番環境（Production）**: 本番稼働環境
- **ステージング環境（Staging）**: 検証・テスト環境

## ディレクトリ構成

```
.
├── docs/                           # ドキュメント
│   ├── 00_RFP/                    # RFP関連資料
│   ├── 01_requirements/           # 要件定義書
│   ├── 02_design/                 # 設計書
│   │   ├── basic/                 # 基本設計書
│   │   └── detailed/              # 詳細設計書
│   └── 03_operations/             # 運用設計書
├── infra/                         # インフラストラクチャコード
│   ├── terraform/                 # Terraformコード
│   │   ├── environments/          # 環境別設定
│   │   │   ├── common/           # 共通系アカウント
│   │   │   ├── prod/             # 本番環境
│   │   │   ├── staging/          # ステージング環境
│   │   │   └── operations/       # 運用系アカウント
│   │   └── modules/              # Terraformモジュール
│   └── modules/                   # 再利用可能なモジュール
├── .github/                       # GitHub設定
│   └── workflows/                 # GitHub Actions
└── scripts/                       # 運用スクリプト
```

## セットアップ

### 前提条件

- AWS CLI v2.x以上
- Terraform v1.5.x以上
- GitHub CLI（オプション）

### 初期セットアップ

```bash
# AWSプロファイル設定
aws configure --profile niigata-common
aws configure --profile niigata-prod
aws configure --profile niigata-staging
aws configure --profile niigata-ops

# Terraform初期化
cd infra/terraform/environments/common
terraform init

cd ../prod
terraform init

cd ../staging
terraform init

cd ../operations
terraform init
```

## デプロイ

### 共通インフラのデプロイ

```bash
cd infra/terraform/environments/common
terraform plan
terraform apply
```

### 本番環境のデプロイ

```bash
cd infra/terraform/environments/prod
terraform plan
terraform apply
```

### ステージング環境のデプロイ

```bash
cd infra/terraform/environments/staging
terraform plan
terraform apply
```

## CI/CD

GitHub Actionsを使用した自動デプロイ：

- **Pull Request作成時**: `terraform plan`を実行
- **mainブランチへのマージ時**: `terraform apply`を実行（承認後）

## セキュリティ

- GCAS（政府情報システムのためのセキュリティ評価制度）準拠
- プライバシーマーク、ISMS認証対応
- 通信の暗号化（TLS 1.2以上）
- 多要素認証（MFA）必須
- AWS Security Hub、GuardDuty有効化

## 監視・運用

- CloudWatch Logs集約
- CloudWatch Alarms設定
- AWS X-Rayによる分散トレーシング
- Amazon Bedrockによる障害一次調査自動化

## ライセンス

このプロジェクトは新潟市の所有物です。

## 連絡先

新潟市福祉部介護保険課
- 電話: 025-226-1269
- メール: kaigo@city.niigata.lg.jp
