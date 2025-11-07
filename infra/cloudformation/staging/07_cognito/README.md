# Cognito CloudFormation Templates (Staging)

## 概要

新潟市介護保険事業所システムのステージング環境用Cognito設定。

本番環境との主な差異：

| 項目 | 本番環境 | ステージング環境 |
|------|---------|---------------|
| MFA | REQUIRED（必須） | OPTIONAL（任意） |
| パスワード最小文字数 | 12文字 | 8文字 |
| 記号必須 | 必須 | 不要 |
| 一時パスワード有効期限 | 1日 | 7日 |
| トークン有効期限 | 30分 | 60分 |

## ファイル構成

```
07_cognito/
├── cognito-dynamodb-tables.yaml      # 本番と同じ（../production/からコピー）
├── cognito-lambda-triggers.yaml      # 本番と同じ（../production/からコピー）
├── cognito-user-pool.yaml            # 本番と同じ（../production/からコピー）
├── cognito-identity-pool.yaml        # 本番と同じ（../production/からコピー）
├── parameters.json                   # ステージング環境固有のパラメータ
├── deploy.sh                         # ステージング環境用デプロイスクリプト
└── README.md                         # このファイル
```

**注意**: CloudFormationテンプレート本体は本番環境と共通です。環境差分は `parameters.json` のみで管理します。

## デプロイ手順

### 1. パラメータ確認

`parameters.json` を確認してください：

```json
{
  "ParameterKey": "Environment",
  "ParameterValue": "stg"
}
```

### 2. デプロイ実行

```bash
# スクリプトに実行権限を付与
chmod +x deploy.sh

# デプロイ実行
./deploy.sh
```

**ステージング環境の利点**:
- 承認プロンプトなし（自動実行）
- MFA任意でテストしやすい
- パスワード設定が緩い（テスト用）

### 3. テストユーザーの作成

```bash
USER_POOL_ID="ap-northeast-1_xxxxxxxxx"

aws cognito-idp admin-create-user \
  --user-pool-id ${USER_POOL_ID} \
  --username test@example.com \
  --user-attributes \
    Name=email,Value=test@example.com \
    Name=name,Value="テスト太郎" \
    Name=family_name,Value="テスト" \
    Name=given_name,Value="太郎" \
    Name=custom:organizationId,Value="ORG-TEST" \
    Name=custom:organizationName,Value="テスト事業所" \
    Name=custom:role,Value="staff" \
  --temporary-password "TestPass123!"
```

## テスト項目

### 基本機能テスト

1. **ユーザー作成**
   ```bash
   aws cognito-idp admin-create-user --user-pool-id ${USER_POOL_ID} --username test@example.com
   ```

2. **初回ログイン（パスワード変更）**
   - 一時パスワードでログイン
   - 新しいパスワードを設定
   - MFA設定（OPTIONAL なのでスキップ可能）

3. **MFA設定テスト**
   - TOTPアプリでQRコードをスキャン
   - 6桁コードを入力
   - ログイン成功を確認

4. **ログイン試行制限テスト**
   - 故意にパスワードを間違える（5回）
   - アカウントロックを確認
   - 30分後にロック解除を確認

5. **パスワードリセット**
   - パスワード忘れフロー
   - 確認コードメール受信
   - 新しいパスワード設定

### Lambda トリガーテスト

1. **PreAuthentication**
   ```bash
   aws logs tail /aws/lambda/kaigo-subsys-stg-pre-auth --follow
   ```
   - ログイン試行回数がDynamoDBに記録されているか確認

2. **PostAuthentication**
   ```bash
   aws logs tail /aws/lambda/kaigo-subsys-stg-post-auth --follow
   ```
   - ログイン成功ログが出力されているか確認

3. **PostConfirmation**
   ```bash
   aws logs tail /aws/lambda/kaigo-subsys-stg-post-confirm --follow
   ```
   - MFAバックアップコードが生成されているか確認

4. **PreTokenGeneration**
   - IDトークンにカスタムクレームが含まれているか確認
   - `custom:role`, `custom:organizationId` が正しく設定されているか

5. **CustomMessage**
   - メールが日本語で送信されているか確認
   - パスワード再設定メールの内容確認

### DynamoDB テーブルテスト

```bash
# ログイン試行テーブル確認
aws dynamodb scan --table-name kaigo-subsys-stg-login-attempts

# MFAバックアップコードテーブル確認
aws dynamodb scan --table-name kaigo-subsys-stg-mfa-backup-codes
```

## トラブルシューティング

詳細は本番環境のREADMEを参照してください：
[../production/07_cognito/README.md](../production/07_cognito/README.md)

## 本番環境へのプロモーション

ステージング環境でテストが完了したら、本番環境にデプロイします：

```bash
# ステージング環境のテスト完了確認
cd ../production/07_cognito

# 本番環境デプロイ
./deploy.sh
```

**注意事項**:
- 本番環境では承認プロンプトが表示されます
- Change Setを慎重に確認してください
- デプロイ時間帯を考慮してください（営業時間外推奨）

## 関連ドキュメント

- [本番環境README](../production/07_cognito/README.md)
- [Cognito 設計書](../../../../../docs/02_design/detailed/07_cognito_detailed/cognito_design.md)
- [Cognito パラメータ設計](../../../../../docs/02_design/detailed/07_cognito_detailed/cognito_parameters.md)

---

**作成日**: 2025-11-07
**作成者**: coder
**バージョン**: 1.0
