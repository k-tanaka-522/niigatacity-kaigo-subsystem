# アプリケーション基本設計

新潟市介護保険事業所システムのアプリケーション基本設計ドキュメントです。

## 📋 アーキテクチャ概要

### システム構成

```
Internet
   ↓
[CloudFront] → [S3: 介護事業者用フロントエンド（SSG）]
   ↓
[Public ALB] → [ECS: provider-backend-service (.NET Core API)]
                     ↓
                [RDS MySQL Multi-AZ]

Direct Connect（庁内ネットワーク）
   ↓
[Internal ALB] → [ECS: staff-backend-service (.NET Core API)]
                      ↓
                 [RDS MySQL Multi-AZ（共有）]

EventBridge
   ↓
[ECS: batch-service (.NET Core)]
```

### ECS サービス構成

| サービス名 | 用途 | 技術スタック | ALB | アクセス元 |
|----------|------|------------|-----|----------|
| **provider-backend-service** | 介護事業者用API | .NET Core 9 (C#) | Public ALB | インターネット |
| **staff-backend-service** | 市職員用API | .NET Core 9 (C#) | Internal ALB | 庁内のみ（Direct Connect） |
| **batch-service** | バッチ処理 | .NET Core 9 (C#) | - | EventBridge トリガー |

**フロントエンド**:
- **介護事業者用**: S3 + CloudFront（Next.js TypeScript SSG）
- **市職員用**: 庁内Webサーバー（スコープ外、骨格のみ提供）

**合計ECSサービス**: 3つ

---

## 📁 ディレクトリ構成

```
基本設計/
├── 01_概要/
│   ├── システム概要.md
│   ├── アーキテクチャ全体図.md
│   └── 技術選定とADR.md
│
├── 02_介護事業者用/
│   ├── フロントエンド設計.md（Next.js SSG、S3+CloudFront）
│   ├── バックエンド設計.md（.NET Core API、Public ALB）
│   └── 画面遷移図.md
│
├── 03_市職員用/
│   ├── フロントエンド設計.md（庁内Webサーバー、スコープ外）
│   ├── バックエンド設計.md（.NET Core API、Internal ALB）
│   └── 画面遷移図.md
│
├── 04_バッチ処理/
│   ├── バッチ処理設計.md
│   └── スケジュール設計.md
│
└── 05_共通/
    ├── データベース設計.md
    ├── 認証認可設計.md（Cognito）
    └── API設計.md
```

---

## 🔑 設計方針

### 1. セキュリティ境界の明確化

**市職員用APIの完全分離**:
- Internal ALB（庁内ネットワークのみアクセス可）
- セキュリティグループで厳格に制御
- インターネットからアクセス不可（GCAS準拠）

**介護事業者用APIのパブリック公開**:
- Public ALB（インターネット経由）
- WAF による保護
- Cognito MFA による認証

### 2. バックエンドの統合と論理分離

**1つの.NET Coreアプリケーション**を名前空間で論理分離:

```
backend/
├── API/
│   ├── Controllers/
│   │   ├── Provider/    # 介護事業者用エンドポイント
│   │   ├── Staff/       # 市職員用エンドポイント
│   │   └── Common/      # 共通エンドポイント
│   ├── Middleware/
│   └── Program.cs
├── Application/         # ビジネスロジック層
├── Domain/              # ドメインモデル層
└── Infrastructure/      # データアクセス層
```

**メリット**:
- コード共有が容易（認証、ログ、エラーハンドリング）
- Clean Architecture適用
- デプロイが簡単（1つのDockerイメージ）

### 3. フロントエンドの分離

**介護事業者用**:
- Next.js TypeScript（SSG）
- S3 + CloudFront でホスティング
- コスト最適化

**市職員用**:
- Next.js TypeScript（骨格のみ提供）
- 庁内Webサーバーで配信（本プロジェクトのスコープ外）

### 4. データベースの共有

**RDS MySQL Multi-AZ（共有）**:
- スキーマレベルで分離
  - `kaigo_provider`: 介護事業者用
  - `kaigo_staff`: 市職員用
  - `kaigo_common`: 共通
- IAM Policyで分離
- GCAS監査で指摘があれば、RDS分離を検討

---

## 🔧 技術スタック

### フロントエンド

| 項目 | 技術 | 用途 |
|------|------|------|
| フレームワーク | Next.js 14（TypeScript） | SSG/ISR |
| UIライブラリ | React 18 | コンポーネント |
| 状態管理 | React Context + SWR | グローバル状態・API連携 |
| 認証 | AWS Amplify UI + Cognito | 認証UI |
| スタイリング | Tailwind CSS | CSS |

### バックエンド

| 項目 | 技術 | 用途 |
|------|------|------|
| フレームワーク | .NET Core 9 (C#) | RESTful API |
| アーキテクチャ | Clean Architecture | レイヤー分離 |
| ORM | Entity Framework Core 9 | データアクセス |
| 認証 | JWT（Cognito発行） | APIエンドポイント認証 |
| バリデーション | FluentValidation | リクエスト検証 |

### データベース

| 項目 | 技術 | 仕様 |
|------|------|------|
| RDBMS | Amazon RDS MySQL 8.0 | Multi-AZ、db.r5.large |
| キャッシュ | Amazon ElastiCache Redis 7.x | cache.r5.large |

---

## 📊 非機能要件

| 項目 | 要件 | 実現方法 |
|------|------|---------|
| **性能** | 同時接続100名、応答時間3秒以内 | ECS Auto Scaling、ElastiCache |
| **可用性** | 稼働率99.0%以上 | Multi-AZ、ALB、Auto Scaling |
| **セキュリティ** | GCAS準拠、TLS 1.3、MFA | Internal ALB、Cognito、KMS、WAF |
| **拡張性** | 将来的なユーザー数増加 | Auto Scaling（最大20タスク） |

---

## 👥 チーム責任分担

**アプリチーム (@app-team)** が担当:
- フロントエンド開発（Next.js TypeScript）
- バックエンド開発（.NET Core 9 C#）
- データベーススキーマ設計
- API設計
- アプリケーションCI/CD

---

## 🔗 関連ドキュメント

- [インフラ設計](../../インフラ設計/README.md) - インフラチーム担当
- [00_RFP](../../../00_RFP/) - 要求仕様書
- [01_requirements](../../../01_requirements/) - 要件定義

---

## 📝 変更履歴

変更履歴はGitコミットログを参照してください。
