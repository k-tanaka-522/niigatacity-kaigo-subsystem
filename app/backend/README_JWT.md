# JWT 認証ミドルウェア - 使い方ガイド

## 概要

このバックエンド API は、Amazon Cognito が発行した JWT トークンによる認証を実装しています。

### 認証フロー

```
1. ユーザーがフロントエンドでログイン
   ↓
2. Cognito が JWT トークンを発行
   ↓
3. フロントエンドが API リクエスト時に Authorization ヘッダーにトークンを付与
   ↓
4. バックエンドが JWT トークンを検証
   - Issuer 検証（Cognito User Pool が正しいか）
   - Audience 検証（Client ID が正しいか）
   - 署名検証（改ざんされていないか）
   - 有効期限検証（期限切れでないか）
   ↓
5. 検証成功 → API 実行、検証失敗 → 401 Unauthorized
```

---

## 環境変数設定

### appsettings.json の設定

```json
{
  "Cognito": {
    "Region": "ap-northeast-1",
    "UserPoolId": "ap-northeast-1_XXXXXXXX",
    "ClientId": "xxxxxxxxxxxxxxxxxxxx"
  }
}
```

### 設定値の取得方法

#### 1. AWS Management Console から取得

```bash
# User Pool ID の取得
1. AWS Console → Cognito → User pools
2. User pool を選択
3. "User pool ID" をコピー（例: ap-northeast-1_XXXXXXXX）

# Client ID の取得
1. 同じ User pool の画面で "App integration" タブ
2. "App clients and analytics" セクション
3. Client ID をコピー（例: xxxxxxxxxxxxxxxxxxxx）
```

#### 2. AWS CLI で取得

```bash
# User Pool ID の取得
aws cognito-idp list-user-pools --max-results 10 --region ap-northeast-1

# Client ID の取得
aws cognito-idp list-user-pool-clients \
  --user-pool-id ap-northeast-1_XXXXXXXX \
  --region ap-northeast-1
```

#### 3. CloudFormation の Output から取得

```bash
# CloudFormation スタックから取得
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-cognito-prod \
  --query "Stacks[0].Outputs" \
  --region ap-northeast-1
```

### 環境変数による上書き（本番環境）

```bash
# 環境変数で appsettings.json を上書き可能
export Cognito__Region="ap-northeast-1"
export Cognito__UserPoolId="ap-northeast-1_XXXXXXXX"
export Cognito__ClientId="xxxxxxxxxxxxxxxxxxxx"

# または .env ファイル（dotenv 使用時）
Cognito__Region=ap-northeast-1
Cognito__UserPoolId=ap-northeast-1_XXXXXXXX
Cognito__ClientId=xxxxxxxxxxxxxxxxxxxx
```

---

## JWT トークンの取得方法（テスト用）

### 1. Cognito でユーザーを作成

```bash
# 管理者が新規ユーザーを作成
aws cognito-idp admin-create-user \
  --user-pool-id ap-northeast-1_XXXXXXXX \
  --username user@example.com \
  --user-attributes \
    Name=email,Value=user@example.com \
    Name=name,Value="山田太郎" \
    Name=custom:organizationId,Value="ORG-001" \
    Name=custom:organizationName,Value="〇〇介護事業所" \
    Name=custom:role,Value="org_admin" \
  --region ap-northeast-1
```

### 2. 初回パスワード変更

```bash
# 一時パスワードでログイン → 新パスワード設定
aws cognito-idp admin-initiate-auth \
  --user-pool-id ap-northeast-1_XXXXXXXX \
  --client-id xxxxxxxxxxxxxxxxxxxx \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters \
    USERNAME=user@example.com,PASSWORD=TemporaryPassword123! \
  --region ap-northeast-1

# レスポンスで ChallengeName: NEW_PASSWORD_REQUIRED が返る

# 新パスワードを設定
aws cognito-idp admin-respond-to-auth-challenge \
  --user-pool-id ap-northeast-1_XXXXXXXX \
  --client-id xxxxxxxxxxxxxxxxxxxx \
  --challenge-name NEW_PASSWORD_REQUIRED \
  --challenge-responses \
    USERNAME=user@example.com,NEW_PASSWORD=NewPassword123! \
  --session "セッショントークン" \
  --region ap-northeast-1
```

### 3. トークン取得

```bash
# ログインしてトークンを取得
aws cognito-idp admin-initiate-auth \
  --user-pool-id ap-northeast-1_XXXXXXXX \
  --client-id xxxxxxxxxxxxxxxxxxxx \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters \
    USERNAME=user@example.com,PASSWORD=NewPassword123! \
  --region ap-northeast-1

# レスポンス例:
# {
#   "AuthenticationResult": {
#     "AccessToken": "eyJraWQiOiJ...",
#     "IdToken": "eyJraWQiOiJ...",
#     "RefreshToken": "eyJjdHkiOiJ...",
#     "ExpiresIn": 3600,
#     "TokenType": "Bearer"
#   }
# }
```

### 4. API テスト

#### curl でのテスト

```bash
# ID トークンを使用（ユーザー情報が含まれる）
TOKEN="eyJraWQiOiJ..."

curl -H "Authorization: Bearer ${TOKEN}" \
  https://localhost:7001/api/applications
```

#### Swagger UI でのテスト

```
1. https://localhost:7001/swagger にアクセス
2. 右上の "Authorize" ボタンをクリック
3. "Bearer {token}" を入力（{token} は ID トークン）
4. "Authorize" をクリック
5. API エンドポイントをテスト
```

---

## API エンドポイントでの使い方

### 基本的な認証

```csharp
using Microsoft.AspNetCore.Authorization;
using NiigataKaigo.API.Helpers;

[ApiController]
[Route("api/[controller]")]
public class ApplicationsController : ControllerBase
{
    /// <summary>
    /// 認証必須のエンドポイント
    /// </summary>
    [Authorize]
    [HttpGet]
    public async Task<IActionResult> GetApplications()
    {
        // ユーザー情報を取得
        var userId = JwtHelper.GetUserId(User);
        var organizationId = JwtHelper.GetOrganizationId(User);
        var role = JwtHelper.GetRole(User);

        // ロールに応じてデータフィルタリング
        if (JwtHelper.CanAccessAllOrganizations(User))
        {
            // system_admin または auditor → 全事業所のデータ
            return Ok(await _service.GetAllApplicationsAsync());
        }
        else
        {
            // org_admin または staff → 自事業所のみ
            return Ok(await _service.GetApplicationsByOrganizationAsync(organizationId));
        }
    }
}
```

### ロールベースアクセス制御（RBAC）

```csharp
using NiigataKaigo.API.Authorization;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    /// <summary>
    /// システム管理者のみアクセス可能
    /// </summary>
    [RoleRequirement("system_admin")]
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        await _service.DeleteUserAsync(id);
        return NoContent();
    }

    /// <summary>
    /// システム管理者または事業所管理者がアクセス可能
    /// </summary>
    [RoleRequirement("system_admin", "org_admin")]
    [HttpPost]
    public async Task<IActionResult> CreateUser([FromBody] CreateUserDto dto)
    {
        var user = await _service.CreateUserAsync(dto);
        return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
    }

    /// <summary>
    /// 監査担当者も閲覧可能
    /// </summary>
    [RoleRequirement("system_admin", "org_admin", "auditor")]
    [HttpGet]
    public async Task<IActionResult> GetUsers()
    {
        return Ok(await _service.GetUsersAsync());
    }
}
```

### リソースベースアクセス制御（事業所IDチェック）

```csharp
using Microsoft.AspNetCore.Authorization;
using NiigataKaigo.API.Authorization;
using NiigataKaigo.API.Helpers;

[ApiController]
[Route("api/[controller]")]
public class ApplicationsController : ControllerBase
{
    private readonly IAuthorizationService _authorizationService;

    public ApplicationsController(IAuthorizationService authorizationService)
    {
        _authorizationService = authorizationService;
    }

    /// <summary>
    /// 申請を取得（事業所IDチェック付き）
    /// </summary>
    [Authorize]
    [HttpGet("{id}")]
    public async Task<IActionResult> GetApplication(int id)
    {
        // DB から申請データを取得
        var application = await _service.GetApplicationByIdAsync(id);
        if (application == null)
        {
            return NotFound();
        }

        // 事業所IDによるアクセス制御
        // 影響: 他事業所の申請データにアクセスできないようにする
        var authorizationResult = await _authorizationService.AuthorizeAsync(
            User,
            new OrganizationAccessRequirement(application.OrganizationId));

        if (!authorizationResult.Succeeded)
        {
            return Forbid(); // 403 Forbidden
        }

        return Ok(application);
    }
}
```

---

## トラブルシューティング

### 1. "Cognito:UserPoolId is not configured" エラー

**原因**: appsettings.json に Cognito 設定が記載されていない

**解決方法**:
```json
{
  "Cognito": {
    "Region": "ap-northeast-1",
    "UserPoolId": "ap-northeast-1_XXXXXXXX",
    "ClientId": "xxxxxxxxxxxxxxxxxxxx"
  }
}
```

### 2. "401 Unauthorized" エラー

**原因**: JWT トークンが無効、または有効期限切れ

**確認方法**:
1. トークンの有効期限を確認（jwt.io でデコード）
2. トークンが正しい形式か確認（`Bearer {token}`）
3. ログを確認（`JWT authentication failed: ...`）

**解決方法**:
- リフレッシュトークンで新しいトークンを取得
- 再ログインしてトークンを取得

### 3. "403 Forbidden" エラー

**原因**: ロールまたは事業所IDによるアクセス制御で失敗

**確認方法**:
1. JWT トークンに `custom:role` クレームが含まれているか
2. JWT トークンに `custom:organizationId` クレームが含まれているか
3. ログを確認（`Authorization failed: User {UserId} with role {Role} is not in allowed roles`）

**解決方法**:
- Cognito User Pool でユーザーのカスタム属性を確認
- PreTokenGeneration Lambda でカスタムクレームが正しく追加されているか確認

### 4. "Invalid JWT signature" エラー

**原因**: トークン署名が不正（改ざんの可能性）

**確認方法**:
1. トークンが Cognito から発行されたものか確認
2. MetadataAddress が正しいか確認
3. Cognito User Pool ID が正しいか確認

**解決方法**:
- 正しい Cognito User Pool から発行されたトークンを使用
- appsettings.json の設定を確認

### 5. カスタムクレームが取得できない

**原因**: PreTokenGeneration Lambda が設定されていない

**確認方法**:
1. Cognito User Pool の Lambda トリガー設定を確認
2. PreTokenGeneration Lambda が正しく実装されているか確認
3. Lambda のログを確認

**解決方法**:
- PreTokenGeneration Lambda を実装（cognito_design.md 参照）
- Lambda で `custom:role` と `custom:organizationId` をトークンに追加

---

## セキュリティ考慮事項

### 1. トークンの保存場所

- **フロントエンド**:
  - ID トークン: メモリ（変数）
  - アクセストークン: メモリ（変数）
  - リフレッシュトークン: HttpOnly Cookie（XSS 対策）

- **バックエンド**:
  - トークンは保存しない（ステートレス認証）

### 2. HTTPS 必須

本番環境では HTTPS を必須とします。

```csharp
// Program.cs
if (!app.Environment.IsDevelopment())
{
    app.UseHsts(); // HTTP Strict Transport Security
    app.UseHttpsRedirection(); // HTTP → HTTPS リダイレクト
}
```

### 3. CORS 設定

本番環境では許可するオリジンを明示的に指定します。

```json
{
  "Cors": {
    "AllowedOrigins": ["https://example.com", "https://www.example.com"]
  }
}
```

### 4. ログ出力

JWT 検証エラーは詳細にログ出力されます（JwtErrorHandlingMiddleware）。

```
[Warning] JWT token expired for user user@example.com at /api/applications
[Error] Invalid JWT signature detected at /api/applications. Possible tampering attempt.
```

---

## 参考ドキュメント

- **Cognito 設計**: `docs/02_design/detailed/07_cognito_detailed/cognito_design.md`
- **C# コーディング規約**: `.claude/docs/40_standards/43_csharp.md`
- **JWT 仕様**: https://jwt.io/
- **Cognito JWT 検証**: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-verifying-a-jwt.html

---

**作成日**: 2025-11-07
**作成者**: Coder Agent
**バージョン**: 1.0
