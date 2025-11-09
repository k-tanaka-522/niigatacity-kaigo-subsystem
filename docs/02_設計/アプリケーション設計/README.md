# アプリケーション設計

新潟市介護保険事業所システムのアプリケーション設計ドキュメントです。

## 📁 ディレクトリ構成

```
アプリケーション設計/
├── 基本設計/                  # アプリケーション基本設計
└── 詳細設計/                  # アプリケーション詳細設計
```

## 📖 設計フェーズ

### 基本設計

- [基本設計/](基本設計/README.md) - アーキテクチャ、フロントエンド、バックエンド、データベース設計など

### 詳細設計

- [詳細設計/](詳細設計/) - ECS詳細、Cognito詳細、API詳細など

## 👥 担当チーム

**アプリチーム (@app-team)**

アプリケーション設計の変更は、アプリチームのレビューが必要です。

## 🔗 関連ドキュメント

- [インフラ設計](../インフラ設計/README.md) - インフラチーム担当
- [00_RFP](../../00_RFP/) - 要求仕様書
- [01_requirements](../../01_requirements/) - 要件定義

## 🔧 実装コード

実際のアプリケーションコードは以下にあります:
- Backend (.NET Core 9 C#): [app/backend/](../../../app/backend/)
- Frontend (Next.js TypeScript): [app/frontend/](../../../app/frontend/)

## 📋 アプリケーション構成

### 介護事業者用アプリ
- フロントエンド: Next.js (TypeScript)
- バックエンド: .NET Core 9 (C#) API
- 認証: Amazon Cognito + MFA

### 市職員用アプリ
- フロントエンド: Next.js (TypeScript)
- バックエンド: .NET Core 9 (C#) API + 管理機能
- 認証: Amazon Cognito + MFA

### バッチ処理
- .NET Core 9 (C#)
- EventBridge トリガー

## 📝 変更履歴

変更履歴はGitコミットログを参照してください。
