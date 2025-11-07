# Cognito CloudFormation Templates

## 概要

新潟市介護保険事業所システムの認証・認可機能を提供するCognito関連リソースのCloudFormationテンプレート集。

- **User Pool**: ユーザー認証、MFA、パスワードポリシー（GCAS準拠）
- **Identity Pool**: AWSリソースへのアクセス制御（S3、API Gateway）
- **Lambda Triggers**: 認証前後の処理、トークンカスタマイズ
- **DynamoDB**: ログイン試行管理、MFAバックアップコード

## ファイル構成

```
07_cognito/
├── cognito-dynamodb-tables.yaml      # DynamoDBテーブル（ログイン試行、MFAバックアップ）
├── cognito-lambda-triggers.yaml      # Lambda トリガー（5関数）
├── cognito-user-pool.yaml            # Cognito User Pool、MFA、パスワードポリシー
├── cognito-identity-pool.yaml        # Cognito Identity Pool、IAMロール
├── parameters.json                   # パラメータファイル（本番環境）
├── deploy.sh                         # デプロイスクリプト
└── README.md                         # このファイル
```

## デプロイ順序（依存関係）

```
1. DynamoDB Tables
   ↓
2. Lambda Triggers（DynamoDB テーブル名を参照）
   ↓
3. User Pool（Lambda ARNを参照）
   ↓
4. Identity Pool（User Pool IDを参照）
```

**重要**: `deploy.sh` スクリプトは依存関係を自動解決します。

## 前提条件

### 必須

- AWS CLI v2以上
- jq コマンド（パラメータ生成に使用）
- 適切なIAM権限（CloudFormation、Cognito、Lambda、DynamoDB、IAM）

### 推奨

- 本番環境デプロイ前にステージング環境でテスト
- Change Setを確認してから実行

## デプロイ手順

### 1. パラメータ確認

`parameters.json` を確認し、環境に合わせて調整してください：

```json
{
  "ParameterKey": "UserPoolName",
  "ParameterValue": "kaigo-subsys-prod-user-pool"
}
```

### 2. デプロイ実行

```bash
# スクリプトに実行権限を付与
chmod +x deploy.sh

# デプロイ実行（Change Sets必須）
./deploy.sh
```

### 3. デプロイ確認

デプロイ中に各Change Setの詳細が表示されます：

```
====================================
Change Set Details: kaigo-subsys-prod-cognito-dynamodb
====================================
Action   LogicalId               Type                        Replacement
------   ---------               ----                        -----------
Add      LoginAttemptsTable      AWS::DynamoDB::Table        N/A
Add      MfaBackupCodesTable     AWS::DynamoDB::Table        N/A
```

### 4. 本番環境の承認プロンプト

本番環境（prod）では、Change Set実行時に承認プロンプトが表示されます：

```
Execute Change Set 'kaigo-subsys-prod-cognito-user-pool-20250107-123456' on kaigo-subsys-prod-cognito-user-pool? (yes/no):
```

`yes` と入力して Enter を押してください。

## デプロイ後の確認

### User Pool ID の取得

```bash
aws cloudformation describe-stacks \
  --stack-name kaigo-subsys-prod-cognito-user-pool \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text
```

### テストユーザーの作成

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
    Name=custom:organizationId,Value="ORG-001" \
    Name=custom:organizationName,Value="〇〇介護事業所" \
    Name=custom:role,Value="staff" \
  --temporary-password "TempPass123!@#"
```

### ログイン試行テーブルの確認

```bash
aws dynamodb scan \
  --table-name kaigo-subsys-prod-login-attempts \
  --max-items 10
```

### Lambda 関数のログ確認

```bash
# PreAuthentication Lambda のログ
aws logs tail /aws/lambda/kaigo-subsys-prod-pre-auth --follow

# PostAuthentication Lambda のログ
aws logs tail /aws/lambda/kaigo-subsys-prod-post-auth --follow
```

## トラブルシューティング

### エラー: "Stack does not exist"

**原因**: 初回デプロイ時の正常なメッセージです。

**対処**: そのまま続行してください。Change Set Type が CREATE に設定されます。

### エラー: "No changes detected"

**原因**: テンプレートに変更がありません。

**対処**: 変更が必要な場合は、テンプレートまたはパラメータを修正してから再実行してください。

### エラー: "User Pool already exists"

**原因**: User Pool は削除せずに更新する必要があります。

**対処**: `deploy.sh` は UPDATE モードで実行されます。削除が必要な場合は、以下のコマンドで手動削除してください：

```bash
aws cloudformation delete-stack --stack-name kaigo-subsys-prod-cognito-user-pool
```

### Lambda 関数が実行されない

**原因**: Cognito と Lambda の権限設定が不足している可能性があります。

**対処**: `cognito-user-pool.yaml` の Lambda Invocation Permissions を確認してください。

### DynamoDB テーブルが見つからない

**原因**: Lambda 関数の環境変数が正しく設定されていない可能性があります。

**対処**: Lambda 関数の環境変数を確認してください：

```bash
aws lambda get-function-configuration \
  --function-name kaigo-subsys-prod-pre-auth \
  --query 'Environment'
```

## ロールバック

### Change Set の削除（実行前）

Change Set を確認して実行したくない場合：

```bash
aws cloudformation delete-change-set \
  --stack-name kaigo-subsys-prod-cognito-user-pool \
  --change-set-name kaigo-subsys-prod-cognito-user-pool-20250107-123456
```

### スタックのロールバック

デプロイ後に問題が発生した場合：

```bash
# User Pool のロールバック
aws cloudformation rollback-stack \
  --stack-name kaigo-subsys-prod-cognito-user-pool

# 完了まで待機
aws cloudformation wait stack-rollback-complete \
  --stack-name kaigo-subsys-prod-cognito-user-pool
```

### 全スタックの削除（開発環境のみ）

**警告**: 本番環境では実行しないでください。

```bash
# 依存関係の逆順で削除
aws cloudformation delete-stack --stack-name kaigo-subsys-prod-cognito-identity-pool
aws cloudformation delete-stack --stack-name kaigo-subsys-prod-cognito-user-pool
aws cloudformation delete-stack --stack-name kaigo-subsys-prod-cognito-lambda
aws cloudformation delete-stack --stack-name kaigo-subsys-prod-cognito-dynamodb
```

## セキュリティ考慮事項

### パスワードポリシー（GCAS準拠）

- 最小文字数: 12文字
- 大文字・小文字・数字・記号必須
- 一時パスワード有効期限: 1日
- パスワード有効期限: 90日（Lambda で実装）

### MFA必須

- TOTP（推奨）: Google Authenticator、Microsoft Authenticator
- SMS（バックアップ）: 携帯電話番号
- バックアップコード: 10個生成（DynamoDB に保存）

### アカウントロックアウト

- ログイン試行制限: 5回 / 15分
- ロックアウト時間: 30分
- ロック解除: 管理者による手動解除 または 30分経過後

### トークン有効期限

- アクセストークン: 30分
- IDトークン: 30分
- リフレッシュトークン: 30日

## フロントエンド連携

### Next.js での設定例

```typescript
// lib/cognito.ts
import { CognitoUserPool } from 'amazon-cognito-identity-js';

const poolData = {
  UserPoolId: process.env.NEXT_PUBLIC_USER_POOL_ID!, // ap-northeast-1_xxxxxxxxx
  ClientId: process.env.NEXT_PUBLIC_USER_POOL_CLIENT_ID! // xxxxxxxxxxxxxxxxxxxxxxxxxx
};

export const userPool = new CognitoUserPool(poolData);
```

### 環境変数設定

`.env.local`:
```
NEXT_PUBLIC_USER_POOL_ID=ap-northeast-1_xxxxxxxxx
NEXT_PUBLIC_USER_POOL_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_IDENTITY_POOL_ID=ap-northeast-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

## 関連ドキュメント

- [Cognito 設計書](../../../../../docs/02_design/detailed/07_cognito_detailed/cognito_design.md)
- [Cognito パラメータ設計](../../../../../docs/02_design/detailed/07_cognito_detailed/cognito_parameters.md)
- [CloudFormation 技術標準](../../../../../.claude/docs/40_standards/45_cloudformation.md)

## サポート

問題が発生した場合は、以下を確認してください：

1. CloudFormation スタックのイベントログ
2. Lambda 関数の CloudWatch Logs
3. Cognito の監査ログ（CloudTrail）

---

**作成日**: 2025-11-07
**作成者**: coder
**バージョン**: 1.0
