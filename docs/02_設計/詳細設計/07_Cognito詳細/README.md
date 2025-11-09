# Cognito 認証・認可 詳細設計

本ディレクトリには、Amazon Cognito を使用した認証・認可機能の詳細設計が含まれています。

## ドキュメント構成

| ドキュメント | 概要 |
|------------|------|
| [cognito_design.md](./cognito_design.md) | Cognito ユーザープール・Identity Pool・RBAC設計 |
| [cognito_parameters.md](./cognito_parameters.md) | CloudFormation パラメータ定義 |
| [authentication_flow.md](./authentication_flow.md) | 認証フロー詳細 |
| [mfa_setup.md](./mfa_setup.md) | MFA設定手順 |

## 前提条件

- セキュリティ要件: GCAS準拠
- MFA: 必須（SMS または TOTP）
- パスワードポリシー: 12文字以上、大小英数字・記号必須
- セッションタイムアウト: 30分
- パスワード有効期限: 90日

## 参照ドキュメント

- [セキュリティ設計](../../basic/07_security/security_design.md)
- [技術標準: セキュリティ](../../../../.claude/docs/40_standards/49_security.md)

---

**作成日**: 2025-11-07
**作成者**: Architect
**バージョン**: 1.0
