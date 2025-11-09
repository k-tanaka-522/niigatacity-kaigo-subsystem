# AWS Amplify SDK 統合ガイド

このドキュメントでは、フロントエンド（Next.js）での AWS Amplify SDK を使用した Cognito 認証の統合について説明します。

---

## 📦 インストール

```bash
cd app/frontend
npm install
```

**追加された依存関係**:
- `aws-amplify` (v6.0.0+)
- `@aws-amplify/ui-react` (v6.0.0+)

---

## 🔧 環境変数の設定

### 1. `.env.local` ファイルを作成

`.env.example` をコピーして `.env.local` を作成します。

```bash
cp .env.example .env.local
```

### 2. Cognito設定値を取得

CloudFormationスタック `07_cognito` のOutputsから以下の値を取得します。

```bash
# CloudFormation Outputs確認
aws cloudformation describe-stacks \
  --stack-name niigata-kaigo-prod-cognito \
  --query 'Stacks[0].Outputs'
```

**取得する値**:
| 環境変数 | CloudFormation Output | 説明 |
|---------|----------------------|------|
| `NEXT_PUBLIC_COGNITO_USER_POOL_ID` | `UserPoolId` | Cognito User Pool ID（例: `ap-northeast-1_XXXXXXXX`） |
| `NEXT_PUBLIC_COGNITO_CLIENT_ID` | `WebAppClientId` | Webアプリクライアントのクライアント<br>ID |
| `NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID` | `IdentityPoolId` | Cognito Identity Pool ID |
| `NEXT_PUBLIC_API_ENDPOINT` | - | バックエンドAPIのエンドポイント（開発: `http://localhost:5000`、本番: ALB DNS） |

### 3. `.env.local` に値を設定

```bash
NEXT_PUBLIC_COGNITO_USER_POOL_ID=ap-northeast-1_abcdefg
NEXT_PUBLIC_COGNITO_CLIENT_ID=1234567890abcdefghijklmnop
NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID=ap-northeast-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
NEXT_PUBLIC_API_ENDPOINT=http://localhost:5000
```

---

## 🚀 開発サーバー起動

```bash
npm run dev
```

ブラウザで http://localhost:3000 にアクセス。

---

## 📂 ファイル構成

```
app/frontend/
├── src/
│   ├── lib/
│   │   ├── amplify-config.ts       # Amplify設定（Cognitoとの接続）
│   │   └── api-client.ts           # APIクライアント（JWT自動付与）
│   ├── services/
│   │   └── auth.service.ts         # 認証サービス（Amplify SDKラッパー）
│   ├── contexts/
│   │   └── AuthContext.tsx         # 認証コンテキスト（グローバル認証状態）
│   ├── types/
│   │   └── auth.ts                 # 認証関連の型定義
│   └── app/
│       ├── layout.tsx              # AuthProvider適用
│       └── login/
│           └── page.tsx            # ログイン画面（MFA対応）
├── .env.local                      # 環境変数（Gitにコミットしない）
├── .env.example                    # 環境変数テンプレート
└── README_AMPLIFY.md               # 本ドキュメント
```

---

## 🔐 認証フロー

### 1. ログイン（パスワード認証）

**ユーザー操作**:
1. ログイン画面（`/login`）でメールアドレスとパスワードを入力
2. 「ログイン」ボタンをクリック

**内部処理**:
```typescript
// AuthContext.tsx
const response = await login(email, password);

if (response.isSignedIn) {
  // 認証完了 → ダッシュボードへ
  router.push('/dashboard');
} else if (response.nextStep) {
  // MFAチャレンジ → MFA画面へ
  setStep('mfa');
}
```

### 2. MFA確認（TOTP）

**ユーザー操作**:
1. 認証アプリ（Google Authenticator等）に表示された6桁のコードを入力
2. 「確認」ボタンをクリック

**内部処理**:
```typescript
const response = await confirmMfa(totpCode);

if (response.isSignedIn) {
  // 認証完了 → ダッシュボードへ
  router.push('/dashboard');
}
```

### 3. 初回パスワード変更

**ユーザー操作**:
1. 新しいパスワード（12文字以上、複雑性要件を満たす）を入力
2. 「パスワードを変更」ボタンをクリック

**内部処理**:
```typescript
const response = await completeNewPassword(newPassword);

if (response.isSignedIn) {
  // 認証完了 → ダッシュボードへ
  router.push('/dashboard');
} else if (response.nextStep?.challengeName === 'SOFTWARE_TOKEN_MFA') {
  // パスワード変更後、MFAチャレンジ → MFA画面へ
  setStep('mfa');
}
```

---

## 🔑 JWTトークンの自動付与

バックエンドAPIへのすべてのリクエストに、自動的にJWTトークンが付与されます。

### APIクライアントの使用

```typescript
import apiClient from '@/lib/api-client';

// GET リクエスト例
const applications = await apiClient.get('/api/applications');

// POST リクエスト例
const newApplication = await apiClient.post('/api/applications', {
  applicationType: 'new',
  title: '新規申請'
});
```

**内部動作**:
1. リクエスト送信前に、Cognitoから最新のJWTトークンを取得
2. `Authorization: Bearer <JWT>` ヘッダーを自動付与
3. バックエンドでJWT検証

**401エラー時の自動処理**:
- トークンが無効または期限切れの場合
- 自動的にログアウト処理を実行
- ログイン画面（`/login`）にリダイレクト

---

## 🧪 テストユーザーの作成

### 管理者によるユーザー作成

```bash
aws cognito-idp admin-create-user \
  --user-pool-id ap-northeast-1_XXXXXXXX \
  --username test@example.com \
  --user-attributes \
    Name=email,Value=test@example.com \
    Name=email_verified,Value=true \
    Name=family_name,Value=テスト \
    Name=given_name,Value=太郎 \
    Name=custom:organization_id,Value=org001 \
    Name=custom:organization_name,Value=テスト事業所 \
    Name=custom:role,Value=staff \
  --temporary-password 'TempPass123!' \
  --message-action SUPPRESS
```

### 初回ログイン手順

1. ログイン画面でメールアドレス（`test@example.com`）と一時パスワード（`TempPass123!`）を入力
2. 「新しいパスワードを設定してください」画面が表示される
3. パスワード要件を満たす新しいパスワードを入力
   - 12文字以上
   - 大文字・小文字・数字・記号を含む
   - 例: `NewPassword@2025`
4. パスワード変更完了後、MFA設定画面が表示される（実装予定）
5. 認証完了後、ダッシュボードにリダイレクト

---

## 🛠️ トラブルシューティング

### 1. `NEXT_PUBLIC_COGNITO_USER_POOL_ID が設定されていません`

**原因**: 環境変数が設定されていない

**解決方法**:
1. `.env.local` ファイルが存在するか確認
2. CloudFormationのOutputsから正しい値をコピー
3. 開発サーバーを再起動（`npm run dev`）

### 2. `UserNotFoundException`

**原因**: Cognito User Poolにユーザーが存在しない

**解決方法**:
管理者によるユーザー作成（上記参照）

### 3. `NotAuthorizedException`

**原因**: パスワードが間違っている

**解決方法**:
- 正しいパスワードを入力
- 一時パスワードの場合は、管理者に確認

### 4. `CodeMismatchException`

**原因**: MFAコードが間違っている

**解決方法**:
- 認証アプリに表示されている最新のコードを入力
- コードの有効期限は30秒

### 5. バックエンドAPIが401エラー

**原因**: JWTトークンが無効または期限切れ

**解決方法**:
- 自動的にログアウトされる
- 再度ログインしてください

### 6. CORS エラー

**原因**: バックエンドのCORS設定が不足

**解決方法**:
バックエンドの `Program.cs` でCORS設定を確認
```csharp
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:3000")
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});
```

---

## 📚 参考リンク

- [AWS Amplify v6 ドキュメント](https://docs.amplify.aws/javascript/)
- [Cognito User Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html)
- [Next.js App Router](https://nextjs.org/docs/app)

---

## 🔒 セキュリティベストプラクティス

1. **環境変数の管理**
   - `.env.local` は `.gitignore` に含める（Gitにコミットしない）
   - 本番環境では環境変数を環境ごとに管理（AWS Systems Manager Parameter Store等）

2. **JWTトークンの保存**
   - Amplify SDKがセキュアに管理（LocalStorage/SessionStorage）
   - カスタムでlocalStorageに保存しない

3. **MFA必須化**
   - 本番環境では全ユーザーにMFAを強制推奨

4. **パスワードポリシー**
   - 12文字以上、複雑性要件を満たす
   - 定期的なパスワード変更を推奨

---

## ✅ チェックリスト

実装完了後、以下を確認してください:

- [ ] `.env.local` にCognito設定値が正しく設定されている
- [ ] 開発サーバーが起動する（`npm run dev`）
- [ ] ログイン画面が表示される（`http://localhost:3000/login`）
- [ ] テストユーザーでログインできる
- [ ] MFA画面が表示される（MFA設定済みユーザーの場合）
- [ ] 認証完了後、ダッシュボードにリダイレクトされる
- [ ] バックエンドAPIへのリクエストにJWTトークンが付与される
- [ ] 401エラー時に自動的にログアウトされる

---

**作成日**: 2025-11-07
**対象バージョン**: Next.js 14.1.0, AWS Amplify 6.0.0
