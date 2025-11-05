# 新潟市介護保険事業所システム

新潟市内の介護保険事業所向けの申請管理Webアプリケーションです。

## 技術スタック

### バックエンド
- **.NET Core 8** (C#)
- **ASP.NET Core Web API**
- **Entity Framework Core** (MySQL対応)
- **JWT認証**
- **Swagger/OpenAPI** (APIドキュメント)

### フロントエンド
- **Next.js 14** (App Router)
- **TypeScript**
- **TailwindCSS**
- **React Hook Form**
- **SWR** (データフェッチング)
- **Axios** (HTTP クライアント)

### データベース
- **MySQL 8.0**

### インフラ
- **Docker & Docker Compose**
- **AWS ECS Fargate** (デプロイ先)
- **AWS RDS** (MySQL)

## 主要機能

### ユーザー機能
- ログイン/ログアウト (JWT認証)
- ユーザー登録 (管理者のみ)

### 申請管理
- 申請書類の新規作成
- 申請書類の一覧表示
- 申請書類の詳細表示
- 申請の提出
- 申請の審査 (承認/却下) - 市役所職員のみ

### ダッシュボード
- 統計情報表示 (全申請数、下書き、提出済み、承認済み)
- クイックアクション

## ディレクトリ構造

```
app/
├── backend/                    # .NET Core Web API
│   ├── Controllers/           # APIコントローラー
│   ├── Models/                # データモデル
│   ├── Data/                  # DbContext
│   ├── DTOs/                  # データ転送オブジェクト
│   ├── Program.cs             # エントリーポイント
│   ├── appsettings.json       # 設定ファイル
│   ├── Dockerfile             # Docker設定
│   └── NiigataKaigo.API.csproj
│
├── frontend/                   # Next.js フロントエンド
│   ├── src/
│   │   ├── app/               # App Router ページ
│   │   ├── components/        # Reactコンポーネント
│   │   ├── lib/               # API クライアント
│   │   └── types/             # TypeScript型定義
│   ├── public/                # 静的ファイル
│   ├── Dockerfile             # Docker設定
│   ├── package.json
│   ├── tsconfig.json
│   ├── tailwind.config.ts
│   └── next.config.js
│
├── db/
│   └── init.sql               # データベース初期化スクリプト
│
├── docker-compose.yml         # Docker Compose設定
└── README.md                  # このファイル
```

## セットアップ & 起動

### 前提条件
- Docker Desktop インストール済み
- Git インストール済み

### ローカル環境での起動

```bash
# リポジトリクローン
git clone https://github.com/k-tanaka-522/niigatacity-kaigo-subsystem.git
cd niigatacity-kaigo-subsystem/app

# Docker Composeで起動
docker-compose up -d

# ログ確認
docker-compose logs -f
```

### アクセス

- **フロントエンド**: http://localhost:3000
- **バックエンドAPI**: http://localhost:8080
- **Swagger UI**: http://localhost:8080/swagger

### サンプルユーザー

| メールアドレス | パスワード | 役割 |
|---------------|-----------|------|
| staff1@example.com | password123 | 事業所職員1 |
| staff2@example.com | password123 | 事業所職員2 |
| admin@example.com | password123 | 管理者 |
| city@example.com | password123 | 市役所職員 |

## 開発

### バックエンド開発

```bash
cd backend

# 依存関係復元
dotnet restore

# ビルド
dotnet build

# 実行
dotnet run
```

### フロントエンド開発

```bash
cd frontend

# 依存関係インストール
npm install

# 開発サーバー起動
npm run dev

# ビルド
npm run build

# 本番モード起動
npm start
```

### データベースマイグレーション

```bash
cd backend

# マイグレーション作成
dotnet ef migrations add InitialCreate

# データベース更新
dotnet ef database update
```

## AWS ECS Fargateへのデプロイ

### ECRへのイメージプッシュ

```bash
# ECRログイン
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com

# バックエンドイメージビルド&プッシュ
cd backend
docker build -t niigata-kaigo-backend .
docker tag niigata-kaigo-backend:latest <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/niigata-kaigo-backend:latest
docker push <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/niigata-kaigo-backend:latest

# フロントエンドイメージビルド&プッシュ
cd ../frontend
docker build -t niigata-kaigo-frontend .
docker tag niigata-kaigo-frontend:latest <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/niigata-kaigo-frontend:latest
docker push <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com/niigata-kaigo-frontend:latest
```

### CloudFormationでデプロイ

インフラリポジトリのECS CloudFormationテンプレートを使用してデプロイします。

```bash
cd ../../infra/cloudformation

# ECSスタックデプロイ
./scripts/deploy.sh production 04_compute ecs-stack
```

## API エンドポイント

### 認証

- `POST /api/auth/login` - ログイン
- `POST /api/auth/register` - ユーザー登録

### 申請

- `GET /api/applications` - 申請一覧取得
- `GET /api/applications/{id}` - 申請詳細取得
- `POST /api/applications` - 申請作成
- `POST /api/applications/{id}/submit` - 申請提出
- `POST /api/applications/{id}/review` - 申請審査

### ヘルスチェック

- `GET /health` - ヘルスチェック

## データベーススキーマ

### テーブル

- **offices** - 介護保険事業所
- **users** - ユーザー（職員）
- **applications** - 申請書類
- **application_files** - 添付ファイル

詳細は [db/init.sql](db/init.sql) を参照。

## セキュリティ

- JWT認証
- BCryptパスワードハッシュ化
- CORS設定
- SSL/TLS通信 (本番環境)
- SQL Injection対策 (Entity Framework Core)

## ライセンス

本プロジェクトは新潟市の所有物です。

## お問い合わせ

- 新潟市福祉部介護保険課
- 電話: 025-226-1269
- Email: kaigo@city.niigata.lg.jp
