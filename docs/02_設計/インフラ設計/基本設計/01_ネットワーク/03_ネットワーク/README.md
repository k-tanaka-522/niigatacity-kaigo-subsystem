# 03_network ディレクトリ

## このディレクトリについて

このディレクトリには、ネットワーク設計（VPC、Transit Gateway、Direct Connect）が含まれています。

**注意**: Transit Gateway と Direct Connect は高額・回線手配が必要なため、Phase 1では実装を保留します。

## 含まれるファイル

| ファイル名 | 説明 | 読む順序 |
|----------|------|---------|
| `network_design.md` | ネットワーク設計書（VPC、サブネット、ルーティング） | 1 |
| `network_diagram.md` | ネットワーク構成図（Mermaid） | 2 |
| `vpc_parameters.md` | VPCパラメータシート（具体的な値） | 3 |
| `transit_gateway_parameters.md` | Transit Gateway パラメータシート ★実装保留 | 4 |
| `README.md` | このファイル（ディレクトリの説明） | - |

## 読み方

1. **`network_design.md`**: ネットワーク設計の全体像を理解
2. **`network_diagram.md`**: 図で視覚的に確認
3. **`vpc_parameters.md`**: 具体的なパラメータ値を確認
4. **`transit_gateway_parameters.md`**: Transit Gateway の設定値を確認

## このディレクトリの役割

- VPC設計（CIDR、サブネット）
- Transit Gateway によるアカウント間接続
- Direct Connect によるオンプレミス接続
- ルーティング設計

---

**次のディレクトリ**: [04_compute](../04_compute/)
