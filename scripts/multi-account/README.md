# Multi-Account対応スクリプト

このディレクトリには、Multi-Account構成でのCloudFormationデプロイをサポートするスクリプトが含まれています。

## 📁 ファイル一覧

| ファイル名 | 目的 | 使い方 |
|----------|------|--------|
| `account-mapping.json` | アカウントID管理 | ローカル実行時にアカウントIDを取得 |
| `get-account-id.sh` | アカウントID取得 | 環境・アカウント種別からアカウントIDを取得 |
| `assume-role.sh` | AssumeRole実行 | 指定されたアカウントにAssumeRole |
| `test-assume-role.sh` | AssumeRoleテスト | AssumeRoleが正常に動作するかテスト |
| `update-parameters.sh` | パラメーター更新 | Common AccountのOutputsをApp Accountに注入 |

---

## 🎯 用途

### 1. GitHub Actions CI/CD

GitHub Actions実行時、CI/CD専用アカウントから各環境アカウントにAssumeRoleします。

**フロー**:
```
CI/CD Account (OIDC認証)
  ↓ AssumeRole
Production/Staging Common Account → Network Stack デプロイ
  ↓ AssumeRole
Production/Staging App Account → ECS/RDS Stack デプロイ
```

### 2. ローカル開発

ローカル実行時は、AWS Profileを切り替えることで複数アカウントを操作します。

**AWS Profile命名規則**:
```
niigata-kaigo-{environment}-{account-type}

例:
  niigata-kaigo-production-common
  niigata-kaigo-production-app
  niigata-kaigo-staging-common
  niigata-kaigo-staging-app
  niigata-kaigo-dev-common
  niigata-kaigo-dev-app
```

---

## 📖 使い方

### 1. アカウントID取得

```bash
# GitHub Actions実行時（環境変数から取得）
export AWS_PROD_COMMON_ACCOUNT_ID=111111111111
ACCOUNT_ID=$(./scripts/multi-account/get-account-id.sh production common)
echo "Account ID: ${ACCOUNT_ID}"
# → 111111111111

# ローカル実行時（account-mapping.json から取得）
ACCOUNT_ID=$(./scripts/multi-account/get-account-id.sh staging app)
echo "Account ID: ${ACCOUNT_ID}"
# → 444444444444
```

**環境変数名（GitHub Secrets）**:
- `AWS_PROD_COMMON_ACCOUNT_ID` - Production Common Account ID
- `AWS_PROD_APP_ACCOUNT_ID` - Production App Account ID
- `AWS_STAGING_COMMON_ACCOUNT_ID` - Staging Common Account ID
- `AWS_STAGING_APP_ACCOUNT_ID` - Staging App Account ID

### 2. AssumeRole実行

```bash
# GitHub Actions実行時（AssumeRole実行）
export GITHUB_ACTIONS=true
export GITHUB_RUN_ID=123456789
export AWS_EXTERNAL_ID=your-external-id
export AWS_PROD_COMMON_ACCOUNT_ID=111111111111

source ./scripts/multi-account/assume-role.sh production common
# → AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN がセット

# ローカル実行時（AWS Profile切り替え）
source ./scripts/multi-account/assume-role.sh staging app
# → AWS_PROFILE=niigata-kaigo-staging-app がセット
```

### 3. AssumeRoleテスト

```bash
# AssumeRoleが正常に動作するかテスト
./scripts/multi-account/test-assume-role.sh production common

# 成功例:
# ========================================
# ✅ AssumeRole成功
# ========================================
# Account ID: 111111111111
```

### 4. パラメーターファイル更新

```bash
# Common AccountのNetwork StackからTransit Gateway IDを取得し、
# App Accountのパラメーターファイルに注入
./scripts/multi-account/update-parameters.sh production

# 更新内容:
#   TransitGatewayId: tgw-0123456789abcdef0
#   TransitGatewayRouteTableId: tgw-rtb-0123456789abcdef0
```

---

## 🔐 セキュリティ要件

### GitHub Secrets設定

以下のSecretsをGitHubリポジトリに設定する必要があります:

| Secret名 | 説明 | 例 |
|---------|------|-----|
| `AWS_PROD_COMMON_ACCOUNT_ID` | Production Common Account ID | `111111111111` |
| `AWS_PROD_APP_ACCOUNT_ID` | Production App Account ID | `222222222222` |
| `AWS_STAGING_COMMON_ACCOUNT_ID` | Staging Common Account ID | `333333333333` |
| `AWS_STAGING_APP_ACCOUNT_ID` | Staging App Account ID | `444444444444` |
| `AWS_EXTERNAL_ID` | AssumeRole用External ID | `unique-external-id-12345` |

### IAM Role設定

各環境アカウントに以下のIAM Roleを作成する必要があります:

**Role名**: `GitHubActionsDeployRole`

**信頼関係**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::{CI_CD_ACCOUNT_ID}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "your-external-id"
        }
      }
    }
  ]
}
```

**ポリシー**:
- `CloudFormationFullAccess`
- `IAMFullAccess`（Change Sets作成に必要）
- その他、デプロイに必要な権限

---

## 🔄 デプロイフロー（Multi-Account）

### Common Account → App Account の順序

**1. Common Account: Network Stack**
```bash
# Common Accountに切り替え
source ./scripts/multi-account/assume-role.sh production common

# Network Stack Change Set作成
./scripts/create-changeset.sh \
  niigata-kaigo-production-common-network-stack \
  infra/common/cloudformation/stacks/02-network/main.yaml \
  infra/common/cloudformation/parameters/production.json \
  production

# Change Set内容確認
./scripts/describe-changeset.sh \
  niigata-kaigo-production-common-network-stack \
  niigata-kaigo-production-common-network-stack-changeset-20251112-083000

# Change Set実行
./scripts/execute-changeset.sh \
  niigata-kaigo-production-common-network-stack \
  niigata-kaigo-production-common-network-stack-changeset-20251112-083000
```

**2. App Account: パラメーター更新**
```bash
# Transit Gateway IDをパラメーターファイルに注入
./scripts/multi-account/update-parameters.sh production
```

**3. App Account: Network Stack**
```bash
# App Accountに切り替え
source ./scripts/multi-account/assume-role.sh production app

# Network Stack Change Set作成
./scripts/create-changeset.sh \
  niigata-kaigo-production-app-network-stack \
  infra/app/cloudformation/stacks/02-network/main.yaml \
  infra/app/cloudformation/parameters/production.json \
  production

# Change Set実行
./scripts/execute-changeset.sh \
  niigata-kaigo-production-app-network-stack \
  niigata-kaigo-production-app-network-stack-changeset-20251112-084000
```

---

## 🛠️ トラブルシューティング

### AssumeRole失敗

**症状**:
```
❌ Error: AssumeRole failed (maximum retries reached)
```

**原因と対処**:
1. **IAM Roleが存在しない**
   - 各環境アカウントに `GitHubActionsDeployRole` を作成

2. **信頼関係が正しくない**
   - CI/CD AccountのARNが正しく設定されているか確認

3. **External IDが正しくない**
   - GitHub Secrets `AWS_EXTERNAL_ID` が正しく設定されているか確認

4. **権限が不足**
   - IAM Roleに必要なポリシーがアタッチされているか確認

### パラメーター更新失敗

**症状**:
```
❌ Error: TransitGatewayId が取得できませんでした
```

**原因と対処**:
1. **Common Account Network Stackが存在しない**
   - Common Accountに Network Stack をデプロイ

2. **Stack名が間違っている**
   - 命名規則を確認: `niigata-kaigo-{environment}-common-network-stack`

3. **Outputsが定義されていない**
   - Network Stackテンプレートで `TransitGatewayId` がOutputに含まれているか確認

---

## 📚 参考資料

- `.claude/docs/02_設計/基本設計/10_インフラ/14_Multi-Account_CICD_設計.md` - Multi-Account CI/CD設計
- `docs/02_設計/基本設計/10_インフラ/02_ネットワーク設計.md` - ネットワーク設計
- `.github/workflows/` - GitHub Actions ワークフロー定義

---

**作成日**: 2025-11-12
**作成者**: Claude (Coder Agent)
**レビュー状態**: Draft
