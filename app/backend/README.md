# 新潟市介護保険事業所システム - バックエンドAPI

介護保険事業所の申請管理・事業所管理を行うWebアプリケーションのバックエンドAPI実装です。

## 技術スタック

- **フレームワーク**: ASP.NET Core 9.0
- **言語**: C# 12.0
- **ORM**: Entity Framework Core 9.0
- **データベース**: MySQL 8.0+
- **認証**: JWT Bearer Authentication
- **パスワードハッシュ**: BCrypt.Net
- **APIドキュメント**: Swagger / OpenAPI 3.0

## ディレクトリ構成

```
app/backend/
├── Controllers/                  # APIコントローラー
│   ├── AuthController.cs         # 認証API（ログイン・ユーザー登録）
│   └── ApplicationsController.cs # 申請管理API
├── Models/                       # エンティティモデル
│   ├── User.cs                   # ユーザーモデル
│   ├── Office.cs                 # 事業所モデル
│   ├── Application.cs            # 申請モデル
│   └── ApplicationFile.cs        # 申請ファイルモデル
├── DTOs/                         # データ転送オブジェクト
│   ├── AuthDTOs.cs               # 認証関連DTO
│   └── ApplicationDTOs.cs        # 申請関連DTO
├── Data/                         # データベースコンテキスト
│   └── ApplicationDbContext.cs   # EF Core DbContext
├── Program.cs                    # アプリケーションエントリーポイント
├── appsettings.json              # 設定ファイル
└── NiigataKaigo.API.csproj       # プロジェクトファイル
```

### ディレクトリの役割

| ディレクトリ | 役割 | 説明 |
|------------|------|------|
| `Controllers/` | API層 | HTTPリクエストのハンドリング、レスポンス生成 |
| `Models/` | ドメイン層 | データベーステーブルに対応するエンティティ |
| `DTOs/` | データ転送層 | クライアントとの入出力データ構造定義 |
| `Data/` | データアクセス層 | Entity Framework Core の DbContext、マイグレーション |

## セットアップ

### 前提条件

- .NET 9 SDK
- MySQL 8.0 以上
- Visual Studio 2022 / Visual Studio Code / Rider（推奨IDE）

### インストール手順

```bash
# プロジェクトディレクトリへ移動
cd app/backend

# 依存パッケージの復元
dotnet restore

# データベース接続設定（appsettings.json）
# 以下の設定を環境に合わせて変更
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=niigata_kaigo;User=root;Password=password;"
  }
}

# データベースマイグレーション実行
dotnet ef database update

# 開発サーバーの起動
dotnet run

# ビルド（本番用）
dotnet build -c Release

# 本番サーバーの起動
dotnet run -c Release
```

### データベース接続設定

`appsettings.json` で以下の設定を変更してください：

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=niigata_kaigo;User=root;Password=password;"
  },
  "Jwt": {
    "Key": "YourSuperSecretKeyForJWTAuthentication123!MustBeLongEnough",
    "Issuer": "NiigataKaigoAPI",
    "Audience": "NiigataKaigoClient"
  }
}
```

**重要**: 本番環境では環境変数または Azure Key Vault を使用してシークレット情報を管理してください。

### データベースマイグレーション

```bash
# マイグレーションファイルの作成
dotnet ef migrations add InitialCreate

# データベースへのマイグレーション適用
dotnet ef database update

# マイグレーションの削除（必要な場合）
dotnet ef migrations remove
```

### 開発サーバー

開発サーバーは以下のURLで起動します：

- **API**: http://localhost:5000
- **HTTPS API**: https://localhost:5001
- **Swagger UI**: https://localhost:5001/swagger

```bash
dotnet run
```

## APIエンドポイント一覧

### 認証API (`/api/auth`)

| メソッド | エンドポイント | 説明 | 認証 |
|---------|---------------|------|------|
| `POST` | `/api/auth/login` | ログイン（JWT トークン発行） | 不要 |
| `POST` | `/api/auth/register` | ユーザー登録 | 必要（admin） |

**ログイン例**:

```bash
curl -X POST https://localhost:5001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "password123"
  }'
```

**レスポンス例**:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "admin@example.com",
    "name": "管理者",
    "role": "admin",
    "officeId": null,
    "officeName": null
  }
}
```

### 申請管理API (`/api/applications`)

| メソッド | エンドポイント | 説明 | 認証 |
|---------|---------------|------|------|
| `GET` | `/api/applications` | 申請一覧取得（ページネーション・フィルタリング） | 必要 |
| `GET` | `/api/applications/{id}` | 申請詳細取得 | 必要 |
| `POST` | `/api/applications` | 申請作成（下書き） | 必要 |
| `PUT` | `/api/applications/{id}` | 申請更新（下書きのみ） | 必要 |
| `DELETE` | `/api/applications/{id}` | 申請削除（下書きのみ） | 必要 |
| `POST` | `/api/applications/{id}/submit` | 申請提出 | 必要 |
| `POST` | `/api/applications/{id}/review` | 申請審査（承認/却下） | 必要（admin/city_staff） |

**申請一覧取得例**:

```bash
curl -X GET 'https://localhost:5001/api/applications?status=submitted&page=1&pageSize=20' \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**レスポンスヘッダー**:
- `X-Total-Count`: 総件数
- `X-Page`: 現在のページ
- `X-Page-Size`: ページサイズ

**申請作成例**:

```bash
curl -X POST https://localhost:5001/api/applications \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "applicationType": "new_service",
    "title": "訪問介護サービス新規指定申請",
    "content": "訪問介護サービスの新規指定を申請します。"
  }'
```

**申請審査例**:

```bash
curl -X POST https://localhost:5001/api/applications/1/review \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "approved": true,
    "comment": "要件を満たしているため承認します。"
  }'
```

### ヘルスチェック (`/health`)

| メソッド | エンドポイント | 説明 | 認証 |
|---------|---------------|------|------|
| `GET` | `/health` | APIの稼働状態確認 | 不要 |

```bash
curl https://localhost:5001/health
# {"status":"healthy","timestamp":"2025-11-07T00:00:00Z"}
```

## 技術仕様

### JWT認証

ASP.NET Core の JWT Bearer Authentication を使用しています。

**認証フロー**:
1. `/api/auth/login` でログイン → JWT トークン取得
2. 以降のAPIリクエストに `Authorization: Bearer {token}` ヘッダーを付与
3. トークンの有効期限は8時間

**トークンに含まれる情報**:
- ユーザーID (`sub`)
- メールアドレス (`email`)
- 氏名 (`name`)
- ロール (`role`)
- 事業所ID (`office_id`)

### Entity Framework Core

**データベース接続**:
- Pomelo.EntityFrameworkCore.MySql を使用
- マイグレーションベースのスキーマ管理
- `ApplicationDbContext` で DbSet を定義

**リレーションシップ**:
- `User` ← 1:N → `Application`
- `Office` ← 1:N → `Application`
- `Application` ← 1:N → `ApplicationFile`
- `User` ← N:1 → `Office`

**削除動作**:
- `Office` 削除時: `User.OfficeId` は NULL に設定
- `Application` 削除時: 関連する `ApplicationFile` も削除（CASCADE）

### 非同期処理（async/await）

すべてのデータベース操作・API処理は非同期で実装されています。

```csharp
[HttpGet]
public async Task<ActionResult<List<ApplicationDto>>> GetApplications()
{
    var applications = await _context.Applications
        .Include(a => a.Office)
        .Include(a => a.User)
        .ToListAsync();

    return Ok(applications);
}
```

### CORS設定

フロントエンド（Next.js）からのリクエストを許可するCORS設定が有効です。

```csharp
app.UseCors("AllowFrontend");
// 許可するオリジン: http://localhost:3000, https://localhost:3000
```

本番環境では、実際のフロントエンドのURLに変更してください。

### パスワードハッシュ化

BCrypt.Net を使用してパスワードを安全にハッシュ化しています。

```csharp
// ハッシュ化
var passwordHash = BCrypt.Net.BCrypt.HashPassword(password);

// 検証
var isValid = BCrypt.Net.BCrypt.Verify(password, passwordHash);
```

### ロギング

ASP.NET Core の組み込みロギングを使用しています。

```csharp
_logger.LogInformation("User {UserId} logged in", userId);
_logger.LogError(ex, "Error processing application {ApplicationId}", id);
```

**ログレベル**:
- `Information`: 通常の動作
- `Warning`: 警告
- `Error`: エラー
- `Critical`: 致命的なエラー

## 開発ガイドライン

### コーディング規約

ASP.NET Core のベストプラクティスに準拠しています。

#### 命名規則

- **クラス**: PascalCase（例: `ApplicationsController`）
- **メソッド**: PascalCase（例: `GetApplications`）
- **変数**: camelCase（例: `userId`）
- **定数**: PascalCase（例: `DefaultPageSize`）
- **プライベートフィールド**: _camelCase（例: `_context`）

#### ファイル配置

- 1つのファイルに1つのクラスを定義
- クラス名とファイル名を一致させる
- 関連するDTOは1ファイルにまとめる（例: `AuthDTOs.cs`）

### エラーハンドリング

すべてのAPI処理で try-catch によるエラーハンドリングを実装しています。

```csharp
try
{
    // 処理
    return Ok(result);
}
catch (Exception ex)
{
    _logger.LogError(ex, "Error message");
    return StatusCode(500, new { message = "エラーメッセージ" });
}
```

**HTTPステータスコード**:
- `200 OK`: 成功
- `201 Created`: 作成成功
- `400 Bad Request`: バリデーションエラー
- `401 Unauthorized`: 認証エラー
- `403 Forbidden`: 権限エラー
- `404 Not Found`: リソースが見つからない
- `500 Internal Server Error`: サーバーエラー

### バリデーション

**モデルバリデーション（DTOレベル）**:

```csharp
public class CreateApplicationDto
{
    [Required(ErrorMessage = "申請種別は必須です")]
    public string ApplicationType { get; set; } = string.Empty;

    [Required(ErrorMessage = "タイトルは必須です")]
    [StringLength(200, ErrorMessage = "タイトルは200文字以内で入力してください")]
    public string Title { get; set; } = string.Empty;

    [Required(ErrorMessage = "内容は必須です")]
    public string Content { get; set; } = string.Empty;
}
```

**ビジネスロジックバリデーション（コントローラーレベル）**:

```csharp
if (application.Status != "draft")
{
    return BadRequest(new { message = "下書き状態の申請のみ編集できます" });
}
```

### 権限管理

`[Authorize]` 属性でエンドポイント単位の権限管理を実装しています。

```csharp
[Authorize]                          // 認証必須
[HttpGet]
public async Task<ActionResult<List<ApplicationDto>>> GetApplications() { ... }

[Authorize(Roles = "admin")]         // admin ロール必須
[HttpPost("register")]
public async Task<ActionResult<UserDto>> Register() { ... }

[Authorize(Roles = "admin,city_staff")] // admin または city_staff ロール必須
[HttpPost("{id}/review")]
public async Task<ActionResult> ReviewApplication() { ... }
```

## 今後の拡張

### 1. 事業所管理API

```
GET    /api/offices              # 事業所一覧取得
GET    /api/offices/{id}         # 事業所詳細取得
POST   /api/offices              # 事業所新規作成（admin）
PUT    /api/offices/{id}         # 事業所更新（admin）
DELETE /api/offices/{id}         # 事業所削除（admin）
```

### 2. ドキュメント管理API

```
GET    /api/documents            # ドキュメント一覧取得
GET    /api/documents/{id}       # ドキュメント詳細取得
POST   /api/documents            # ドキュメントアップロード（admin）
GET    /api/documents/{id}/download # ドキュメントダウンロード
DELETE /api/documents/{id}       # ドキュメント削除（admin）
```

### 3. ファイルアップロードAPI

```
POST   /api/applications/{id}/files        # 申請ファイルアップロード
GET    /api/applications/{id}/files        # 申請ファイル一覧取得
GET    /api/applications/{id}/files/{fileId} # 申請ファイルダウンロード
DELETE /api/applications/{id}/files/{fileId} # 申請ファイル削除
```

実装予定技術:
- Azure Blob Storage または S3 との連携
- ウイルススキャン（ClamAV）
- ファイル形式チェック（PDF, Word, Excel のみ許可）
- ファイルサイズ制限（10MB）

### 4. 通知機能

```
GET    /api/notifications        # 通知一覧取得
POST   /api/notifications/{id}/read # 既読にする
```

実装予定技術:
- SignalR によるリアルタイム通知
- メール送信（SendGrid / Amazon SES）

### 5. 監査ログ

```
GET    /api/audit-logs           # 監査ログ一覧取得（admin）
GET    /api/audit-logs/{id}      # 監査ログ詳細取得（admin）
```

記録対象:
- 申請の作成・更新・削除
- 申請の提出・承認・却下
- ユーザーの作成・更新・削除
- ログイン履歴

## テスト

現在はテストが未実装です。今後以下のテストを実装予定：

### ユニットテスト（xUnit）

```bash
dotnet test
```

テスト対象:
- コントローラーのロジック
- ビジネスロジック
- バリデーション

### 統合テスト

テスト対象:
- APIエンドポイントの動作
- データベースアクセス
- 認証フロー

### テストカバレッジ目標

- ビジネスロジック: 80%以上
- コントローラー: 70%以上

## Docker対応

Dockerfile が用意されています。

```bash
# Dockerイメージのビルド
docker build -t niigata-kaigo-backend .

# Dockerコンテナの起動
docker run -p 5000:80 -p 5001:443 niigata-kaigo-backend
```

Docker Compose での実行（MySQL含む）:

```bash
docker-compose up -d
```

## トラブルシューティング

### ポート5000/5001が使用中の場合

`Properties/launchSettings.json` で以下のポート設定を変更してください：

```json
{
  "applicationUrl": "https://localhost:5002;http://localhost:5003"
}
```

### データベース接続エラー

```bash
# MySQL の起動確認
mysql -h localhost -u root -p

# 接続文字列の確認
dotnet ef dbcontext info
```

### マイグレーションエラー

```bash
# マイグレーションファイルをすべて削除
rm -rf Migrations/

# 初期化からやり直し
dotnet ef migrations add InitialCreate
dotnet ef database update
```

### JWT トークンエラー

`appsettings.json` の `Jwt:Key` が十分に長いことを確認してください（最低32文字以上推奨）。

### CORS エラー

フロントエンドのオリジンが `Program.cs` の `AllowFrontend` ポリシーに含まれているか確認してください。

## パフォーマンス最適化

### データベースクエリ最適化

- `Include()` で適切なEager Loading
- `Select()` で必要なカラムのみ取得
- `AsNoTracking()` で読み取り専用クエリの高速化

```csharp
var applications = await _context.Applications
    .AsNoTracking()
    .Include(a => a.Office)
    .Include(a => a.User)
    .Select(a => new ApplicationDto { ... })
    .ToListAsync();
```

### ページネーション

大量データを扱う場合は、必ずページネーションを使用してください。

```csharp
.Skip((page - 1) * pageSize)
.Take(pageSize)
```

## セキュリティ

### 実装済み

- ✅ JWT Bearer Authentication
- ✅ パスワードハッシュ化（BCrypt）
- ✅ ロールベースのアクセス制御
- ✅ HTTPS通信（開発環境・本番環境）
- ✅ CORS設定

### 今後の実装予定

- [ ] レート制限（Rate Limiting）
- [ ] SQLインジェクション対策の強化
- [ ] XSS対策の強化
- [ ] CSRF対策
- [ ] ログイン試行回数制限（Account Lockout）
- [ ] パスワード強度ポリシー
- [ ] 二要素認証（2FA）

## 関連ドキュメント

- [ASP.NET Core ドキュメント](https://learn.microsoft.com/ja-jp/aspnet/core/)
- [Entity Framework Core ドキュメント](https://learn.microsoft.com/ja-jp/ef/core/)
- [JWT Authentication](https://jwt.io/)
- [BCrypt.Net](https://github.com/BcryptNet/bcrypt.net)
- [Swagger / OpenAPI](https://swagger.io/)

## ライセンス

本プロジェクトは新潟市介護保険事業所システムの一部です。
