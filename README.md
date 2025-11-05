# 新潟市介護保険事業所システム

## 概要

本リポジトリは、新潟市介護保険事業所システムのフルスタックアプリケーションとAWSインフラストラクチャをコードとして管理するためのものです。

## プロジェクト情報

- **プロジェクト名**: 新潟市介護保険事業所システム導入業務
- **予定価格**: 2億1,000万円（税込）
- **履行期限**: 令和9年1月3日
- **運用保守期間**: 令和9年1月4日～令和13年3月31日

## 技術スタック

### フロントエンド
- **フレームワーク**: Next.js 16 (App Router)
- **言語**: TypeScript
- **スタイリング**: Tailwind CSS
- **認証**: AWS Cognito

### バックエンド
- **フレームワーク**: .NET 8.0 (ASP.NET Core Web API)
- **言語**: C#
- **ORM**: Entity Framework Core
- **データベース**: PostgreSQL 15
- **認証**: JWT Bearer Token (Cognito)
- **ロギング**: Serilog

### インフラストラクチャ
- **クラウドプラットフォーム**: AWS（GCAS準拠）
- **IaC**: CloudFormation
- **CI/CD**: GitHub Actions
- **コンテナオーケストレーション**: Amazon ECS（Fargate）
- **データベース**: Amazon RDS（PostgreSQL）
- **ネットワーク**: AWS Direct Connect、VPC
- **監視**: Amazon CloudWatch、AWS X-Ray
- **AI/ML**: Amazon Bedrock（運用自動化）

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
├── frontend/                       # Next.js フロントエンド
│   ├── app/                       # Next.js App Router
│   ├── components/                # Reactコンポーネント
│   │   ├── ui/                   # UIコンポーネント
│   │   └── features/             # 機能別コンポーネント
│   ├── lib/                      # ユーティリティ・API
│   │   ├── api/                  # APIクライアント
│   │   ├── hooks/                # カスタムフック
│   │   └── utils/                # ユーティリティ関数
│   ├── public/                   # 静的ファイル
│   └── Dockerfile                # フロントエンド用Docker設定
├── backend/                       # .NET Core バックエンド
│   ├── NiigatacityKaigoApi/      # メインAPIプロジェクト
│   │   ├── Controllers/          # APIコントローラー
│   │   ├── Models/               # データモデル
│   │   ├── Services/             # ビジネスロジック
│   │   ├── Repositories/         # データアクセス層
│   │   ├── DTOs/                 # データ転送オブジェクト
│   │   ├── Middleware/           # カスタムミドルウェア
│   │   ├── Configuration/        # 設定・DbContext
│   │   └── Program.cs            # エントリーポイント
│   ├── NiigatacityKaigoApi.Tests/ # 単体テスト
│   ├── Dockerfile                # バックエンド用Docker設定
│   └── NiigatacityKaigoApi.sln   # ソリューションファイル
├── docs/                         # ドキュメント
│   ├── 00_RFP/                   # RFP関連資料
│   ├── 01_requirements/          # 要件定義書
│   ├── 02_design/                # 設計書
│   │   ├── basic/                # 基本設計書
│   │   └── detailed/             # 詳細設計書
│   └── 03_operations/            # 運用設計書
├── infra/                        # インフラストラクチャコード
│   └── cloudformation/           # CloudFormationテンプレート
├── docker-compose.yml            # 開発環境用Docker Compose
├── docker-compose.dev.yml        # 開発用データベース
└── .github/                      # GitHub設定
    └── workflows/                # GitHub Actions
```

## セットアップ

### 前提条件

#### アプリケーション開発
- Node.js v18以上
- .NET SDK 8.0以上
- Docker & Docker Compose
- PostgreSQL 15（またはDockerで起動）

#### インフラストラクチャ
- AWS CLI v2.x以上
- AWS SAM CLI（オプション）
- GitHub CLI（オプション）

### 開発環境セットアップ

#### 1. リポジトリのクローン

```bash
git clone https://github.com/your-org/niigatacity-kaigo-subsystem.git
cd niigatacity-kaigo-subsystem
```

#### 2. Docker Composeで全環境を起動

```bash
# データベース、バックエンド、フロントエンドをまとめて起動
docker-compose up -d

# ログ確認
docker-compose logs -f
```

アクセス:
- フロントエンド: http://localhost:3000
- バックエンドAPI: http://localhost:8080
- Swagger UI: http://localhost:8080/swagger

#### 3. ローカル開発（Docker なし）

**バックエンド (.NET)**

```bash
cd backend

# 依存関係の復元
dotnet restore

# データベース起動（Docker Compose使用）
docker-compose -f ../docker-compose.dev.yml up -d

# マイグレーション実行
cd NiigatacityKaigoApi
dotnet ef database update

# 開発サーバー起動
dotnet run

# テスト実行
cd ../NiigatacityKaigoApi.Tests
dotnet test
```

**フロントエンド (Next.js)**

```bash
cd frontend

# 環境変数設定
cp .env.local.example .env.local

# 依存関係のインストール
npm install

# 開発サーバー起動
npm run dev

# ビルド
npm run build

# 本番モード起動
npm start
```

## 主要機能

### 実装済み機能

1. **要介護認定申請管理**
   - 申請の新規作成・更新・削除
   - 申請一覧表示
   - 申請状態管理（申請中/調査中/審査中/認定済み/却下）
   - 対象者別・事業所別フィルタリング

2. **基本API構造**
   - RESTful API設計
   - JWT認証（AWS Cognito連携準備完了）
   - Swagger/OpenAPI ドキュメント
   - エラーハンドリング
   - ロギング（Serilog）

3. **フロントエンド**
   - レスポンシブデザイン
   - 申請一覧表示
   - API連携フック
   - ローディング・エラー状態管理

### 今後実装予定の機能

- 認定調査票の作成・提出
- 基本チェックリストの提出
- ケアプラン届の提出
- 高齢者福祉サービス申請
- 対象者情報の閲覧
- 過去の審査会資料の閲覧
- OCR処理（AWS Textract連携）
- ファイル無害化

## デプロイ

### アプリケーションのビルド

```bash
# フロントエンドのビルド
cd frontend
npm run build

# バックエンドのビルド
cd backend
dotnet publish -c Release -o out
```

### AWS環境へのデプロイ

CloudFormationテンプレートを使用したデプロイ：

```bash
cd infra/cloudformation

# VPCスタックのデプロイ
aws cloudformation deploy \
  --template-file vpc.yaml \
  --stack-name niigata-kaigo-vpc-prod \
  --parameter-overrides Environment=prod

# ECSスタックのデプロイ
aws cloudformation deploy \
  --template-file ecs.yaml \
  --stack-name niigata-kaigo-ecs-prod \
  --parameter-overrides Environment=prod \
  --capabilities CAPABILITY_IAM

# RDSスタックのデプロイ
aws cloudformation deploy \
  --template-file rds.yaml \
  --stack-name niigata-kaigo-rds-prod \
  --parameter-overrides Environment=prod
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
