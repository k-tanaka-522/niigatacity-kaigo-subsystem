# Cognito CloudFormation パラメータ設計

## 目次

1. [パラメータ一覧](#パラメータ一覧)
2. [環境別パラメータ](#環境別パラメータ)
3. [カスタム属性定義](#カスタム属性定義)
4. [Lambda トリガー仕様](#lambda-トリガー仕様)
5. [CloudFormation テンプレート構成](#cloudformation-テンプレート構成)

---

## パラメータ一覧

### ユーザープール共通パラメータ

| パラメータ名 | 型 | デフォルト値 | 説明 |
|------------|---|------------|------|
| `ProjectName` | String | `kaigo-subsys` | プロジェクト名 |
| `Environment` | String | - | 環境名（prod / stg） |
| `UserPoolName` | String | `${ProjectName}-${Environment}-user-pool` | ユーザープール名 |
| `UserPoolDomain` | String | `${ProjectName}-${Environment}` | Cognitoドメインプレフィックス |
| `MfaConfiguration` | String | `REQUIRED` | MFA設定（REQUIRED / OPTIONAL / OFF） |
| `PasswordMinLength` | Number | `12` | パスワード最小文字数 |
| `PasswordRequireUppercase` | String | `true` | 大文字必須 |
| `PasswordRequireLowercase` | String | `true` | 小文字必須 |
| `PasswordRequireNumbers` | String | `true` | 数字必須 |
| `PasswordRequireSymbols` | String | `true` | 記号必須 |
| `TemporaryPasswordValidityDays` | Number | `1` | 一時パスワード有効日数 |
| `AccessTokenValidity` | Number | `30` | アクセストークン有効期限（分） |
| `IdTokenValidity` | Number | `30` | IDトークン有効期限（分） |
| `RefreshTokenValidity` | Number | `30` | リフレッシュトークン有効期限（日） |

### Lambda トリガーパラメータ

| パラメータ名 | 型 | デフォルト値 | 説明 |
|------------|---|------------|------|
| `PreAuthFunctionArn` | String | - | PreAuthentication Lambda ARN |
| `PostAuthFunctionArn` | String | - | PostAuthentication Lambda ARN |
| `PostConfirmFunctionArn` | String | - | PostConfirmation Lambda ARN |
| `PreTokenFunctionArn` | String | - | PreTokenGeneration Lambda ARN |
| `CustomMessageFunctionArn` | String | - | CustomMessage Lambda ARN |

### Identity Pool パラメータ

| パラメータ名 | 型 | デフォルト値 | 説明 |
|------------|---|------------|------|
| `IdentityPoolName` | String | `${ProjectName}-${Environment}-identity-pool` | Identity Pool名 |
| `AllowUnauthenticatedIdentities` | String | `false` | 未認証ユーザー許可 |

---

## 環境別パラメータ

### 本番環境（production）

**parameters/prod.json**:

```json
[
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "kaigo-subsys"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "prod"
  },
  {
    "ParameterKey": "UserPoolName",
    "ParameterValue": "kaigo-subsys-prod-user-pool"
  },
  {
    "ParameterKey": "UserPoolDomain",
    "ParameterValue": "kaigo-subsys-prod"
  },
  {
    "ParameterKey": "MfaConfiguration",
    "ParameterValue": "REQUIRED"
  },
  {
    "ParameterKey": "PasswordMinLength",
    "ParameterValue": "12"
  },
  {
    "ParameterKey": "PasswordRequireUppercase",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "PasswordRequireLowercase",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "PasswordRequireNumbers",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "PasswordRequireSymbols",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "TemporaryPasswordValidityDays",
    "ParameterValue": "1"
  },
  {
    "ParameterKey": "AccessTokenValidity",
    "ParameterValue": "30"
  },
  {
    "ParameterKey": "IdTokenValidity",
    "ParameterValue": "30"
  },
  {
    "ParameterKey": "RefreshTokenValidity",
    "ParameterValue": "30"
  },
  {
    "ParameterKey": "PreAuthFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-prod-pre-auth"
  },
  {
    "ParameterKey": "PostAuthFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-prod-post-auth"
  },
  {
    "ParameterKey": "PostConfirmFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-prod-post-confirm"
  },
  {
    "ParameterKey": "PreTokenFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-prod-pre-token"
  },
  {
    "ParameterKey": "CustomMessageFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-prod-custom-msg"
  },
  {
    "ParameterKey": "IdentityPoolName",
    "ParameterValue": "kaigo-subsys-prod-identity-pool"
  },
  {
    "ParameterKey": "AllowUnauthenticatedIdentities",
    "ParameterValue": "false"
  }
]
```

### ステージング環境（staging）

**parameters/stg.json**:

```json
[
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "kaigo-subsys"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "stg"
  },
  {
    "ParameterKey": "UserPoolName",
    "ParameterValue": "kaigo-subsys-stg-user-pool"
  },
  {
    "ParameterKey": "UserPoolDomain",
    "ParameterValue": "kaigo-subsys-stg"
  },
  {
    "ParameterKey": "MfaConfiguration",
    "ParameterValue": "OPTIONAL"
  },
  {
    "ParameterKey": "PasswordMinLength",
    "ParameterValue": "8"
  },
  {
    "ParameterKey": "PasswordRequireUppercase",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "PasswordRequireLowercase",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "PasswordRequireNumbers",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "PasswordRequireSymbols",
    "ParameterValue": "false"
  },
  {
    "ParameterKey": "TemporaryPasswordValidityDays",
    "ParameterValue": "7"
  },
  {
    "ParameterKey": "AccessTokenValidity",
    "ParameterValue": "60"
  },
  {
    "ParameterKey": "IdTokenValidity",
    "ParameterValue": "60"
  },
  {
    "ParameterKey": "RefreshTokenValidity",
    "ParameterValue": "30"
  },
  {
    "ParameterKey": "PreAuthFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-stg-pre-auth"
  },
  {
    "ParameterKey": "PostAuthFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-stg-post-auth"
  },
  {
    "ParameterKey": "PostConfirmFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-stg-post-confirm"
  },
  {
    "ParameterKey": "PreTokenFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-stg-pre-token"
  },
  {
    "ParameterKey": "CustomMessageFunctionArn",
    "ParameterValue": "arn:aws:lambda:ap-northeast-1:123456789012:function:kaigo-subsys-stg-custom-msg"
  },
  {
    "ParameterKey": "IdentityPoolName",
    "ParameterValue": "kaigo-subsys-stg-identity-pool"
  },
  {
    "ParameterKey": "AllowUnauthenticatedIdentities",
    "ParameterValue": "false"
  }
]
```

**環境差分のポイント**:

| 項目 | 本番環境 | ステージング環境 | 理由 |
|------|----------|-----------------|------|
| MFA | REQUIRED（必須） | OPTIONAL（任意） | 本番はセキュリティ厳格、テストは柔軟性重視 |
| パスワード最小文字数 | 12文字 | 8文字 | 本番はGCAS準拠、テストは簡易 |
| 記号必須 | 必須 | 不要 | 本番は厳格、テストは簡易 |
| 一時パスワード有効期限 | 1日 | 7日 | 本番は短期、テストは長期 |
| トークン有効期限 | 30分 | 60分 | 本番は短期、テストは長期 |

---

## カスタム属性定義

### CloudFormation での定義

```yaml
Resources:
  UserPool:
    Type: AWS::Cognito::UserPool
    Properties:
      UserPoolName: !Ref UserPoolName
      Schema:
        # 標準属性
        - Name: email
          AttributeDataType: String
          Required: true
          Mutable: true
        - Name: phone_number
          AttributeDataType: String
          Required: false
          Mutable: true
        - Name: name
          AttributeDataType: String
          Required: true
          Mutable: true
        - Name: family_name
          AttributeDataType: String
          Required: true
          Mutable: true
        - Name: given_name
          AttributeDataType: String
          Required: true
          Mutable: true

        # カスタム属性
        - Name: organizationId
          AttributeDataType: String
          Mutable: false  # 作成後変更不可
          Required: false
          StringAttributeConstraints:
            MinLength: 1
            MaxLength: 256
        - Name: organizationName
          AttributeDataType: String
          Mutable: true
          Required: false
          StringAttributeConstraints:
            MinLength: 1
            MaxLength: 256
        - Name: role
          AttributeDataType: String
          Mutable: true
          Required: false
          StringAttributeConstraints:
            MinLength: 1
            MaxLength: 256
        - Name: employeeId
          AttributeDataType: String
          Mutable: false  # 作成後変更不可
          Required: false
          StringAttributeConstraints:
            MinLength: 1
            MaxLength: 256
        - Name: department
          AttributeDataType: String
          Mutable: true
          Required: false
          StringAttributeConstraints:
            MinLength: 1
            MaxLength: 256
        - Name: passwordLastChanged
          AttributeDataType: Number
          Mutable: true
          Required: false
          NumberAttributeConstraints:
            MinValue: 0
```

### カスタム属性の制約

| 属性名 | データ型 | 最小長 / 最小値 | 最大長 / 最大値 | 変更可能 | 必須 |
|--------|---------|---------------|---------------|---------|------|
| `organizationId` | String | 1 | 256 | ❌ | ❌ |
| `organizationName` | String | 1 | 256 | ✅ | ❌ |
| `role` | String | 1 | 256 | ✅ | ❌ |
| `employeeId` | String | 1 | 256 | ❌ | ❌ |
| `department` | String | 1 | 256 | ✅ | ❌ |
| `passwordLastChanged` | Number | 0 | - | ✅ | ❌ |

**重要な注意事項**:
- カスタム属性は作成後に**削除できません**
- データ型も**変更できません**
- `Mutable: false` の属性は、ユーザー作成時のみ設定可能

---

## Lambda トリガー仕様

### 1. PreAuthentication

**Lambda関数名**: `kaigo-subsys-${Environment}-pre-auth`

**トリガータイミング**: 認証前

**用途**:
- アカウントロックアウトチェック
- ログイン試行回数チェック
- パスワード有効期限チェック（90日）

**入力イベント**:

```json
{
  "version": "1",
  "triggerSource": "PreAuthentication_Authentication",
  "region": "ap-northeast-1",
  "userPoolId": "ap-northeast-1_xxxxxxxxx",
  "userName": "user@example.com",
  "callerContext": {
    "awsSdkVersion": "aws-sdk-unknown-unknown",
    "clientId": "xxxxxxxxxxxxxxxxxxxxxxxxxx"
  },
  "request": {
    "userAttributes": {
      "sub": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "email": "user@example.com",
      "custom:organizationId": "ORG-001",
      "custom:role": "org_admin",
      "custom:passwordLastChanged": "1699999999"
    },
    "validationData": null
  },
  "response": {}
}
```

**処理ロジック**:

```javascript
exports.handler = async (event) => {
  const userId = event.userName;
  const now = Math.floor(Date.now() / 1000);

  // 1. アカウントロックアウトチェック
  const attempts = await getLoginAttempts(userId);
  if (attempts.lockedUntil && attempts.lockedUntil > now) {
    throw new Error('User account is locked.');
  }

  // 2. ログイン試行回数チェック
  if (attempts.failedAttempts >= 5) {
    await lockUser(userId, now + 1800); // 30分ロック
    throw new Error('Too many failed login attempts.');
  }

  // 3. パスワード有効期限チェック（90日）
  const passwordLastChanged = event.request.userAttributes['custom:passwordLastChanged'];
  if (passwordLastChanged) {
    const daysSinceChange = (now - parseInt(passwordLastChanged)) / 86400;
    if (daysSinceChange > 90) {
      throw new Error('Password expired. Please change your password.');
    }
  }

  return event;
};
```

**必要な権限**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:ap-northeast-1:*:table/kaigo-subsys-prod-login-attempts"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

### 2. PostAuthentication

**Lambda関数名**: `kaigo-subsys-${Environment}-post-auth`

**トリガータイミング**: 認証成功後

**用途**:
- 最終ログイン日時の記録
- ログイン成功ログの出力
- ログイン試行回数のリセット

**処理ロジック**:

```javascript
exports.handler = async (event) => {
  const userId = event.userName;
  const now = Math.floor(Date.now() / 1000);

  // 1. 最終ログイン日時を記録（DynamoDB）
  await updateLastLoginTime(userId, now);

  // 2. ログイン試行回数をリセット
  await resetLoginAttempts(userId);

  // 3. ログ出力
  console.log(JSON.stringify({
    event: 'user_login',
    userId: userId,
    timestamp: now,
    ipAddress: event.request.userContextData?.encodedData
  }));

  return event;
};
```

### 3. PostConfirmation

**Lambda関数名**: `kaigo-subsys-${Environment}-post-confirm`

**トリガータイミング**: ユーザー確認後（初回ログイン時）

**用途**:
- DynamoDBへのユーザー情報登録
- 初回ログイン時の追加設定

**処理ロジック**:

```javascript
exports.handler = async (event) => {
  const userId = event.userName;
  const attributes = event.request.userAttributes;

  // DynamoDBにユーザー情報を登録
  await createUserProfile({
    userId: attributes.sub,
    email: attributes.email,
    name: attributes.name,
    organizationId: attributes['custom:organizationId'],
    role: attributes['custom:role'],
    createdAt: Date.now()
  });

  return event;
};
```

### 4. PreTokenGeneration

**Lambda関数名**: `kaigo-subsys-${Environment}-pre-token`

**トリガータイミング**: トークン生成前

**用途**:
- カスタムクレーム（ロール、事業所ID）の追加

**処理ロジック**:

```javascript
exports.handler = async (event) => {
  const role = event.request.userAttributes['custom:role'];
  const organizationId = event.request.userAttributes['custom:organizationId'];
  const organizationName = event.request.userAttributes['custom:organizationName'];

  // IDトークンにカスタムクレームを追加
  event.response = {
    claimsOverrideDetails: {
      claimsToAddOrOverride: {
        'custom:role': role,
        'custom:organizationId': organizationId,
        'custom:organizationName': organizationName
      }
    }
  };

  return event;
};
```

### 5. CustomMessage

**Lambda関数名**: `kaigo-subsys-${Environment}-custom-msg`

**トリガータイミング**: メール/SMS送信前

**用途**:
- メッセージのカスタマイズ（日本語化）

**処理ロジック**:

```javascript
exports.handler = async (event) => {
  if (event.triggerSource === 'CustomMessage_ForgotPassword') {
    event.response.emailSubject = '【新潟市介護保険事業所システム】パスワード再設定';
    event.response.emailMessage = `
      パスワード再設定用の確認コード: ${event.request.codeParameter}

      このコードを15分以内に入力してください。
    `;
  }

  if (event.triggerSource === 'CustomMessage_AdminCreateUser') {
    event.response.emailSubject = '【新潟市介護保険事業所システム】アカウント作成';
    event.response.emailMessage = `
      ユーザー名: ${event.userName}
      一時パスワード: ${event.request.codeParameter}

      初回ログイン時にパスワードを変更してください。
    `;
  }

  return event;
};
```

---

## CloudFormation テンプレート構成

### ディレクトリ構造

```
infra/cloudformation/
├── stacks/
│   └── 05-cognito/
│       ├── main.yaml                      # 親スタック
│       └── README.md
├── templates/
│   └── cognito/
│       ├── user-pool.yaml                 # ユーザープール定義
│       ├── identity-pool.yaml             # Identity Pool定義
│       ├── user-pool-client.yaml          # アプリクライアント定義
│       ├── iam-roles.yaml                 # IAMロール（認証済みユーザー）
│       └── lambda-triggers/
│           ├── pre-auth.yaml              # PreAuthentication Lambda
│           ├── post-auth.yaml             # PostAuthentication Lambda
│           ├── post-confirm.yaml          # PostConfirmation Lambda
│           ├── pre-token.yaml             # PreTokenGeneration Lambda
│           └── custom-message.yaml        # CustomMessage Lambda
└── parameters/
    ├── prod.json
    └── stg.json
```

### 親スタック（main.yaml）

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Cognito User Pool and Identity Pool

Parameters:
  ProjectName:
    Type: String
  Environment:
    Type: String
    AllowedValues:
      - prod
      - stg
  UserPoolName:
    Type: String
  UserPoolDomain:
    Type: String
  MfaConfiguration:
    Type: String
    AllowedValues:
      - REQUIRED
      - OPTIONAL
      - OFF
  PasswordMinLength:
    Type: Number
    Default: 12
  AccessTokenValidity:
    Type: Number
    Default: 30
  IdTokenValidity:
    Type: Number
    Default: 30
  RefreshTokenValidity:
    Type: Number
    Default: 30

Resources:
  # Lambda トリガー
  PreAuthLambda:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${TemplateBucket}/templates/cognito/lambda-triggers/pre-auth.yaml
      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment

  PostAuthLambda:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${TemplateBucket}/templates/cognito/lambda-triggers/post-auth.yaml
      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment

  PreTokenLambda:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${TemplateBucket}/templates/cognito/lambda-triggers/pre-token.yaml
      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment

  # ユーザープール
  UserPool:
    Type: AWS::CloudFormation::Stack
    DependsOn:
      - PreAuthLambda
      - PostAuthLambda
      - PreTokenLambda
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${TemplateBucket}/templates/cognito/user-pool.yaml
      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment
        UserPoolName: !Ref UserPoolName
        UserPoolDomain: !Ref UserPoolDomain
        MfaConfiguration: !Ref MfaConfiguration
        PasswordMinLength: !Ref PasswordMinLength
        AccessTokenValidity: !Ref AccessTokenValidity
        IdTokenValidity: !Ref IdTokenValidity
        RefreshTokenValidity: !Ref RefreshTokenValidity
        PreAuthFunctionArn: !GetAtt PreAuthLambda.Outputs.FunctionArn
        PostAuthFunctionArn: !GetAtt PostAuthLambda.Outputs.FunctionArn
        PreTokenFunctionArn: !GetAtt PreTokenLambda.Outputs.FunctionArn

  # Identity Pool
  IdentityPool:
    Type: AWS::CloudFormation::Stack
    DependsOn: UserPool
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${TemplateBucket}/templates/cognito/identity-pool.yaml
      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment
        UserPoolId: !GetAtt UserPool.Outputs.UserPoolId
        UserPoolClientId: !GetAtt UserPool.Outputs.UserPoolClientId

Outputs:
  UserPoolId:
    Value: !GetAtt UserPool.Outputs.UserPoolId
    Export:
      Name: !Sub ${ProjectName}-${Environment}-UserPoolId

  UserPoolClientId:
    Value: !GetAtt UserPool.Outputs.UserPoolClientId
    Export:
      Name: !Sub ${ProjectName}-${Environment}-UserPoolClientId

  IdentityPoolId:
    Value: !GetAtt IdentityPool.Outputs.IdentityPoolId
    Export:
      Name: !Sub ${ProjectName}-${Environment}-IdentityPoolId
```

### デプロイコマンド

```bash
# ステージング環境
./scripts/deploy.sh stg 05-cognito

# 本番環境（承認必須）
./scripts/deploy.sh prod 05-cognito
```

---

## 関連ドキュメント

- [cognito_design.md](./cognito_design.md) - Cognito 設計詳細
- [CloudFormation 構成方針](../10_cloudformation/cloudformation_design.md)
- [セキュリティ設計](../../basic/07_security/security_design.md)

---

**作成日**: 2025-11-07
**作成者**: Architect
**バージョン**: 1.0
