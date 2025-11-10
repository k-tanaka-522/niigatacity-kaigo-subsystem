# 全体設計

新潟市介護保険事業所システムの全体設計ドキュメントです。

## 📁 ディレクトリ構成

```
00_全体/
├── 01_概要/                    # プロジェクト概要
├── 02_アカウント構成/          # AWSアカウント構成
└── 10_architecture_diagrams/   # アーキテクチャ図
```

## 📖 ドキュメント一覧

### 01_概要

- [概要.md](01_概要/概要.md) - プロジェクト全体概要
- [draw.io図作成ガイド.md](01_概要/draw.io図作成ガイド.md) - 図作成のガイドライン

### 02_アカウント構成

- [アカウント設計.md](02_アカウント構成/アカウント設計.md) - AWSマルチアカウント構成

### 10_architecture_diagrams

- [overall_architecture.md](10_architecture_diagrams/overall_architecture.md) - 全体アーキテクチャ図
- [network_diagram.md](10_architecture_diagrams/network_diagram.md) - ネットワーク構成図
- [dataflow_diagram.md](10_architecture_diagrams/dataflow_diagram.md) - データフロー図

## 🔗 関連セクション

- [10_インフラ](../10_インフラ/README.md) - インフラ設計（インフラチーム担当）
- [20_アプリケーション](../20_アプリケーション/README.md) - アプリケーション設計（アプリチーム担当）

## 👥 レビュアー

**両チームレビュー必須**
- インフラチーム (@infra-team)
- アプリチーム (@app-team)

全体設計の変更は、両チームの合意が必要です。
