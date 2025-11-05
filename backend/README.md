# 新潟市介護保険事業所システム - バックエンド

## 概要

.NET 8.0 (ASP.NET Core Web API) を使用したバックエンドAPIアプリケーション。

## 技術スタック

- **フレームワーク**: .NET 8.0 (ASP.NET Core Web API)
- **言語**: C# 12
- **ORM**: Entity Framework Core 8.0
- **データベース**: PostgreSQL 15
- **認証**: JWT Bearer Token (AWS Cognito)
- **ロギング**: Serilog
- **テスト**: xUnit, Moq, FluentAssertions
- **ドキュメント**: Swagger/OpenAPI

## プロジェクト構成

```
backend/
├── NiigatacityKaigoApi/           # メインAPIプロジェクト
│   ├── Controllers/               # APIコントローラー
│   │   └── CareApplicationsController.cs
│   ├── Models/                    # データモデル
│   │   ├── CareApplication.cs
│   │   ├── Subject.cs
│   │   ├── AssessmentSurvey.cs
│   │   ├── BasicChecklist.cs
│   │   ├── CarePlan.cs
│   │   └── FacilityUser.cs
│   ├── Services/                  # ビジネスロジック
│   │   ├── IApplicationService.cs
│   │   └── ApplicationService.cs
│   ├── Repositories/              # データアクセス層
│   │   ├── IApplicationRepository.cs
│   │   └── ApplicationRepository.cs
│   ├── DTOs/                      # データ転送オブジェクト
│   │   └── CareApplicationDto.cs
│   ├── Configuration/             # 設定・DbContext
│   │   └── ApplicationDbContext.cs
│   ├── Middleware/                # カスタムミドルウェア
│   ├── Program.cs                 # エントリーポイント
│   ├── appsettings.json          # アプリケーション設定
│   └── NiigatacityKaigoApi.csproj
├── NiigatacityKaigoApi.Tests/    # 単体テスト
│   ├── Services/
│   │   └── ApplicationServiceTests.cs
│   └── NiigatacityKaigoApi.Tests.csproj
├── Dockerfile                     # Docker設定
└── NiigatacityKaigoApi.sln       # ソリューションファイル
```

## 開発環境セットアップ

### 前提条件

- .NET SDK 8.0以上
- PostgreSQL 15（またはDocker）
- Visual Studio 2022 または VS Code + C# Extension

### セットアップ手順

```bash
# 依存関係の復元
dotnet restore

# データベース起動（Docker Compose使用）
docker-compose -f ../docker-compose.dev.yml up -d

# Entity Framework ツールのインストール（初回のみ）
dotnet tool install --global dotnet-ef

# マイグレーション作成（初回のみ）
cd NiigatacityKaigoApi
dotnet ef migrations add InitialCreate

# データベース更新
dotnet ef database update

# 開発サーバー起動
dotnet run
```

ブラウザで以下を開く:
- API: http://localhost:8080
- Swagger UI: http://localhost:8080/swagger

## 利用可能なコマンド

```bash
# 開発サーバー起動
dotnet run

# ホットリロード有効で起動
dotnet watch run

# ビルド
dotnet build

# リリースビルド
dotnet build -c Release

# 公開（デプロイ用）
dotnet publish -c Release -o out

# テスト実行
cd NiigatacityKaigoApi.Tests
dotnet test

# カバレッジ付きテスト
dotnet test /p:CollectCoverage=true

# マイグレーション作成
cd NiigatacityKaigoApi
dotnet ef migrations add MigrationName

# データベース更新
dotnet ef database update

# マイグレーション削除（最新のみ）
dotnet ef migrations remove
```

## データベース

### 接続文字列

`appsettings.json` または `appsettings.Development.json` で設定:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Database=niigatacity_kaigo_dev;Username=postgres;Password=dev_password"
  }
}
```

### マイグレーション

```bash
# 新しいマイグレーション作成
dotnet ef migrations add AddNewField

# データベース更新
dotnet ef database update

# 特定のマイグレーションまで戻す
dotnet ef database update MigrationName
```

## API エンドポイント

### 要介護認定申請

| メソッド | エンドポイント | 説明 |
|---------|---------------|------|
| GET | `/api/CareApplications` | 申請一覧取得 |
| GET | `/api/CareApplications/{id}` | 申請詳細取得 |
| GET | `/api/CareApplications/subject/{subjectId}` | 対象者別申請一覧 |
| GET | `/api/CareApplications/facility/{facilityId}` | 事業所別申請一覧 |
| POST | `/api/CareApplications` | 申請新規作成 |
| PUT | `/api/CareApplications/{id}` | 申請更新 |
| DELETE | `/api/CareApplications/{id}` | 申請削除 |

### ヘルスチェック

| メソッド | エンドポイント | 説明 |
|---------|---------------|------|
| GET | `/health` | ヘルスチェック |

## 認証

### AWS Cognito設定

`appsettings.json` で設定:

```json
{
  "AWS": {
    "Region": "ap-northeast-1",
    "Cognito": {
      "Authority": "https://cognito-idp.ap-northeast-1.amazonaws.com/your_user_pool_id",
      "ClientId": "your_client_id",
      "UserPoolId": "your_user_pool_id"
    }
  }
}
```

### JWT トークン使用例

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:8080/api/CareApplications
```

## ロギング

Serilog を使用:

- コンソール出力
- ファイル出力 (`logs/log-YYYYMMDD.txt`)

ログレベルの設定 (`appsettings.json`):

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "System": "Warning"
      }
    }
  }
}
```

## テスト

### 単体テスト

```bash
cd NiigatacityKaigoApi.Tests
dotnet test

# 詳細出力
dotnet test --logger "console;verbosity=detailed"

# カバレッジレポート生成
dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
```

### 使用しているテストライブラリ

- **xUnit**: テストフレームワーク
- **Moq**: モックライブラリ
- **FluentAssertions**: アサーションライブラリ
- **Microsoft.EntityFrameworkCore.InMemory**: インメモリDB

## アーキテクチャ

### レイヤー構成

```
Controller → Service → Repository → DbContext → Database
     ↓          ↓
    DTO      Domain Model
```

### 主要コンポーネント

- **Controllers**: HTTPリクエストの受付とレスポンス
- **Services**: ビジネスロジックの実装
- **Repositories**: データアクセスの抽象化
- **Models**: ドメインモデル（Entity）
- **DTOs**: データ転送オブジェクト
- **Configuration**: DbContext、DIコンテナ設定

## コーディング規約

- **命名規則**: C# の標準規約に従う
- **非同期**: すべてのI/O処理は非同期（async/await）
- **依存性注入**: インターフェースを介した疎結合
- **Null安全**: Nullable Reference Types 有効化
- **ロギング**: 適切なログレベルで記録

## Docker

### ビルドと実行

```bash
# イメージビルド
docker build -t niigata-kaigo-api .

# コンテナ実行
docker run -p 8080:8080 \
  -e ConnectionStrings__DefaultConnection="Host=postgres;..." \
  niigata-kaigo-api
```

## トラブルシューティング

### データベース接続エラー

1. PostgreSQLが起動しているか確認
2. 接続文字列が正しいか確認
3. データベースが存在するか確認

```bash
# PostgreSQL接続確認
psql -h localhost -U postgres -d niigatacity_kaigo_dev
```

### マイグレーションエラー

```bash
# データベース削除して再作成
dotnet ef database drop
dotnet ef database update
```

## デプロイ

### リリースビルド

```bash
dotnet publish -c Release -o out
```

### Docker デプロイ

```bash
docker build -t niigata-kaigo-api:latest .
docker push your-registry/niigata-kaigo-api:latest
```

## ライセンス

このプロジェクトは新潟市の所有物です。
