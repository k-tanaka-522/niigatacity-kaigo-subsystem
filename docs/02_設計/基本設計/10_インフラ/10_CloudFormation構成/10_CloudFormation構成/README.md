# 10_CloudFormation構成 ディレクトリ

## このディレクトリについて

このディレクトリには、AWS CloudFormation テンプレートの構成方針と実装ガイドラインが含まれています。

## 含まれるファイル

| ファイル名 | 説明 | 読む順序 |
|----------|------|---------|
| `cloudformation_structure.md` | CloudFormation ファイル分割3原則とディレクトリ構造 | 1 |
| `deployment_strategy.md` | デプロイ戦略、Change Sets運用、ロールバック手順 | 2 |
| `stack_lifecycle.md` | スタックのライフサイクル管理と変更頻度別の運用 | 3 |
| `README.md` | このファイル（ディレクトリの説明） | - |

## 読み方

1. **まず `cloudformation_structure.md` を読んでください**
   - ファイル分割3原則を理解できます
   - ディレクトリ構造（stacks/ + templates/ + parameters/）を確認できます
   - クロススタック参照パターンを学べます

2. **次に `deployment_strategy.md` を読んでください**
   - Change Sets を使った安全なデプロイ手順を確認できます
   - デプロイスクリプトの使い方を学べます
   - ロールバック手順を理解できます

3. **最後に `stack_lifecycle.md` を読んでください**
   - スタックの変更頻度別の運用方法を確認できます
   - ライフサイクルに基づくスタック分割の理由を理解できます

## このディレクトリの役割

- CloudFormation テンプレートのファイル分割方針の提示
- ディレクトリ構造の標準化
- デプロイ戦略の明確化
- 実装フェーズへのガイドライン提供

---

**次に読むファイル**: [`cloudformation_structure.md`](./cloudformation_structure.md)
