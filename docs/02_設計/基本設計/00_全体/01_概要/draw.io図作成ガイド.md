# draw.io 図作成ガイド

## 概要

このガイドでは、AWS Architecture Icons 5.0 を使用して、基本設計書で必要な6つの図を draw.io で作成する方法を説明します。

---

## 事前準備

### 1. draw.io のインストール

**Web版**:
- https://app.diagrams.net/

**Desktop版（推奨）**:
- https://github.com/jgraph/drawio-desktop/releases
- Windows / macOS / Linux 対応

### 2. AWS Architecture Icons 5.0 の有効化

1. draw.io を開く
2. 左サイドバー下部の「その他の図形」をクリック
3. 「AWS」カテゴリにチェック
4. 「適用」をクリック

これで AWS サービスのアイコンが左サイドバーに表示されます。

---

## 図1: システム全体構成図

**ファイル名**: `docs/02_design/基本設計/01_概要/システム全体構成図.drawio`

### 構成要素

#### AWS Cloud（グループ）

1. 左サイドバーから「AWS」→「Groups」→「AWS Cloud」を選択
2. キャンバスにドラッグ＆ドロップ
3. サイズ: 幅1560px、高さ1080px
4. テキスト: 「AWS Cloud 東京リージョン（ap-northeast-1）」

#### AWS Organizations

1. 左サイドバーから「AWS」→「Management & Governance」→「AWS Organizations」
2. 左上に配置
3. ラベル: 「AWS Organizations マルチアカウント管理」

#### Transit Gateway（ハブ）

1. 左サイドバーから「AWS」→「Networking & Content Delivery」→「Transit Gateway」
2. 中央に配置（ハブの位置）
3. サイズ: 80x80px
4. ラベル: 「AWS Transit Gateway ハブ&スポークモデル」

#### 本番共通系アカウント

1. 左サイドバーから「AWS」→「Groups」→「Account」
2. 左上に配置
3. 境界線: 点線（dashed）、色: #CD2264（赤）
4. テキスト: 「本番共通系アカウント」

**VPC（10.1.0.0/16）**:
- 左サイドバーから「AWS」→「Groups」→「VPC」
- アカウント内に配置
- テキスト: 「VPC 10.1.0.0/16」

**CloudWatch Logs**:
- 左サイドバーから「AWS」→「Management & Governance」→「CloudWatch」
- VPC内に配置
- ラベル: 「CloudWatch Logs ログ集約」

**CloudTrail**:
- 左サイドバーから「AWS」→「Management & Governance」→「CloudTrail」
- VPC内に配置
- ラベル: 「CloudTrail 監査ログ」

**AWS Config**:
- 左サイドバーから「AWS」→「Management & Governance」→「Config」
- VPC内に配置
- ラベル: 「AWS Config 構成変更履歴」

**TGW Attachment**:
- 小さな Transit Gateway アイコンをVPC下部に配置
- Transit Gateway（ハブ）に線で接続（色: #8C4FFF、太さ: 2px）

#### 本番アプリ系アカウント

1. 左サイドバーから「AWS」→「Groups」→「Account」
2. 右上に配置
3. 境界線: 点線（dashed）、色: #CD2264（赤）
4. テキスト: 「本番アプリ系アカウント」

**VPC（10.2.0.0/16）**:
- VPCグループを配置
- テキスト: 「VPC 10.2.0.0/16」

**ALB**:
- 左サイドバーから「AWS」→「Networking & Content Delivery」→「Elastic Load Balancing」
- VPC内に配置
- ラベル: 「ALB」

**ECS Fargate**:
- 左サイドバーから「AWS」→「Compute」→「Elastic Container Service」
- VPC内、ALBの右に配置
- ラベル: 「ECS Fargate」

**RDS MySQL**:
- 左サイドバーから「AWS」→「Database」→「RDS」
- VPC内、ECSの右に配置
- ラベル: 「RDS MySQL Multi-AZ」

**ElastiCache Redis**:
- 左サイドバーから「AWS」→「Database」→「ElastiCache」
- VPC内、RDSの右に配置
- ラベル: 「ElastiCache Redis」

**Cognito**:
- 左サイドバーから「AWS」→「Security, Identity, & Compliance」→「Cognito」
- VPC内、ElastiCacheの右に配置
- ラベル: 「Cognito MFA認証」

**TGW Attachment**:
- VPC下部に配置
- Transit Gateway（ハブ）に線で接続（色: #8C4FFF、太さ: 2px）

#### ステージング共通系アカウント

1. 本番共通系と同様の構成
2. 左下に配置
3. 境界線: 点線（dashed）、色: #147EBA（青）
4. テキスト: 「ステージング共通系アカウント」
5. VPC: 10.3.0.0/16

#### ステージングアプリ系アカウント

1. 本番アプリ系と同様の構成
2. 右下に配置
3. 境界線: 点線（dashed）、色: #147EBA（青）
4. テキスト: 「ステージングアプリ系アカウント」
5. VPC: 10.4.0.0/16
6. RDS MySQL: ラベルを「RDS MySQL Single-AZ」に変更

#### Direct Connect

1. 左サイドバーから「AWS」→「Networking & Content Delivery」→「Direct Connect」
2. Transit Gateway（ハブ）の下に配置
3. ラベル: 「AWS Direct Connect 100Mbps × 2回線」
4. Transit Gateway（ハブ）に線で接続（色: #8C4FFF、太さ: 3px）

#### オンプレミス

1. 図形: 四角形（Rectangle）
2. Direct Connectの左に配置
3. 塗りつぶし: #f5f5f5、境界線: #666666
4. テキスト: 「オンプレミス 新潟市庁舎」
5. Direct Connectに線で接続（色: #666666、太さ: 3px、点線: dashed）

#### Internet Gateway

1. 左サイドバーから「AWS」→「Networking & Content Delivery」→「Internet Gateway」
2. 右側中央に配置
3. ラベル: 「Internet Gateway」

#### インターネット

1. 図形: 雲（Cloud）
2. Internet Gatewayの上に配置
3. 塗りつぶし: #dae8fc、境界線: #6c8ebf
4. テキスト: 「インターネット」
5. Internet Gatewayに線で接続（色: #6c8ebf、太さ: 2px）

#### DRリージョン（大阪）

1. 図形: 四角形（Rectangle）
2. 右下に配置
3. 塗りつぶし: #fff2cc、境界線: #d6b656、点線: dashed
4. テキスト: 「DR リージョン 大阪（ap-northeast-3） Backup & Restore」
5. 本番アプリ系アカウントに線で接続（色: #d6b656、太さ: 2px、点線: dashed、双方向矢印）

#### 凡例

1. 図形: 四角形（Rectangle）
2. 左下に配置
3. 塗りつぶし: #f5f5f5、境界線: #666666
4. テキスト:
   - 「凡例」（太字）
   - 「本番環境」（色: #CD2264）
   - 「ステージング環境」（色: #147EBA）
   - 「Transit Gateway接続」（色: #8C4FFF）
   - 「Direct Connect接続」（色: #666666）
   - 「DR（Backup & Restore）」（色: #d6b656）

---

## 図2: アカウント構成図

**ファイル名**: `docs/02_design/基本設計/02_アカウント構成/アカウント構成図.drawio`

### 構成要素

#### AWS Organizations

- 最上部に配置
- 「AWS Organizations」アイコン

#### OU（Organizational Unit）: 本番環境

- AWS Organizations の下に配置
- 境界線: #CD2264（赤）、点線
- テキスト: 「OU: 本番環境」

**本番共通系アカウント**:
- OU内に配置
- Accountアイコン
- テキスト: 「本番共通系アカウント 監視・ログ集約」

**本番アプリ系アカウント**:
- OU内に配置
- Accountアイコン
- テキスト: 「本番アプリ系アカウント アプリケーション実行」

#### OU（Organizational Unit）: ステージング環境

- AWS Organizations の下に配置
- 境界線: #147EBA（青）、点線
- テキスト: 「OU: ステージング環境」

**ステージング共通系アカウント**:
- OU内に配置
- Accountアイコン
- テキスト: 「ステージング共通系アカウント 監視・ログ集約」

**ステージングアプリ系アカウント**:
- OU内に配置
- Accountアイコン
- テキスト: 「ステージングアプリ系アカウント アプリケーション実行」

#### SCP（Service Control Policies）

- AWS Organizations の横に配置
- テキスト: 「SCP セキュリティポリシー一元管理」

---

## 図3: ネットワーク構成図

**ファイル名**: `docs/02_design/基本設計/03_ネットワーク/ネットワーク構成図.drawio`

### 構成要素

#### VPC（10.2.0.0/16）本番アプリ系

- VPCグループを配置

#### Availability Zone: ap-northeast-1a

- VPC内に配置
- 境界線: #147EBA、点線
- テキスト: 「AZ-1a」

**Public Subnet（10.2.1.0/24）**:
- Subnetグループ（色: #00A4A6）
- テキスト: 「Public Subnet 10.2.1.0/24」

**NAT Gateway**:
- Public Subnet内に配置
- 「NAT Gateway」アイコン

**Private Subnet（10.2.11.0/24）**:
- Subnetグループ（色: #147EBA）
- テキスト: 「Private Subnet 10.2.11.0/24」

**ALB**:
- Private Subnet内に配置

**ECS Task (Fargate)**:
- Private Subnet内、ALBの右に配置

**Database Subnet（10.2.21.0/24）**:
- Subnetグループ（色: #C925D1）
- テキスト: 「Database Subnet 10.2.21.0/24」

**RDS Primary**:
- Database Subnet内に配置
- 「RDS」アイコン

#### Availability Zone: ap-northeast-1c

- 同様の構成を配置

#### Availability Zone: ap-northeast-1d

- 同様の構成を配置

#### Internet Gateway

- VPCの上部に配置
- Public Subnetに接続

#### Transit Gateway Attachment

- VPCの下部に配置
- Private Subnetに接続

#### Route Table

- 各Subnetにルートテーブルアイコンを配置
- ルーティング先を矢印で示す

---

## 図4: ECS構成図

**ファイル名**: `docs/02_design/基本設計/04_コンピューティング/ECS構成図.drawio`

### 構成要素

#### Application Load Balancer（ALB）

- 左側に配置
- 「Elastic Load Balancing」アイコン

#### Target Group

- ALBの右に配置
- テキスト: 「Target Group」

#### ECS Cluster

- 境界線で囲む
- テキスト: 「ECS Cluster」

**ECS Service**:
- Cluster内に配置
- テキスト: 「ECS Service Auto Scaling有効」

**ECS Task（Fargate） × 3**:
- Service内に3つ配置
- 「ECS」アイコン + 「Fargate」ラベル

#### Security Group（ALB）

- ALBの周りに点線で囲む
- テキスト: 「SG: ALB HTTPS 443」

#### Security Group（ECS）

- ECS Taskの周りに点線で囲む
- テキスト: 「SG: ECS HTTP 8080（ALBからのみ）」

#### CloudWatch Logs

- ECS Taskから矢印
- 「CloudWatch」アイコン
- テキスト: 「ログ出力」

---

## 図5: RDS構成図

**ファイル名**: `docs/02_design/基本設計/05_データベース/RDS構成図.drawio`

### 構成要素

#### Database Subnet Group

- 境界線で囲む
- テキスト: 「Database Subnet Group」

**Subnet: AZ-1a**:
- Subnetグループ
- テキスト: 「Database Subnet 10.2.21.0/24」

**RDS Primary Instance**:
- Subnet内に配置
- 「RDS」アイコン
- テキスト: 「RDS Primary db.r6g.large」

**Subnet: AZ-1c**:
- Subnetグループ
- テキスト: 「Database Subnet 10.2.22.0/24」

**RDS Standby Instance**:
- Subnet内に配置
- 「RDS」アイコン
- テキスト: 「RDS Standby 自動フェイルオーバー」

**同期レプリケーション**:
- Primary → Standby に矢印（双方向）
- テキスト: 「同期レプリケーション」

#### Read Replica（オプション）

- Subnet: AZ-1d
- 「RDS」アイコン
- テキスト: 「Read Replica（将来拡張）」

**非同期レプリケーション**:
- Primary → Read Replica に矢印（単方向）
- テキスト: 「非同期レプリケーション」

#### ECS Task

- Database Subnet Groupの外に配置
- 矢印: ECS Task → RDS Primary（色: #C925D1、太さ: 2px）
- テキスト: 「MySQL 3306」

#### Security Group（RDS）

- Database Subnet Groupの周りに点線で囲む
- テキスト: 「SG: RDS MySQL 3306（ECSからのみ）」

---

## 図6: Cognito認証フロー図

**ファイル名**: `docs/02_design/基本設計/07_セキュリティ/Cognito認証フロー図.drawio`

### 構成要素

#### ユーザー

- 左端に配置
- 人型アイコン
- テキスト: 「ユーザー（事業所職員）」

#### フロントエンド（Next.js）

- ユーザーの右に配置
- 四角形（色: #61DAFB）
- テキスト: 「Next.js フロントエンド」

#### Amazon Cognito User Pool

- 中央に配置
- 「Cognito」アイコン
- テキスト: 「Cognito User Pool MFA必須」

**Lambda Triggers（5つ）**:
1. Pre Sign-up
2. Post Confirmation
3. Pre Authentication
4. Post Authentication
5. Custom Message

各Lambda Triggerを小さな「Lambda」アイコンで表現し、Cognito User Poolの周りに配置

#### DynamoDB（2テーブル）

- Cognito User Poolの右に配置
- 「DynamoDB」アイコン × 2

**テーブル1: Users**:
- テキスト: 「Users テーブル ユーザー情報」

**テーブル2: Sessions**:
- テキスト: 「Sessions テーブル セッション管理」

#### Amazon Cognito Identity Pool

- Cognito User Poolの下に配置
- 「Cognito」アイコン
- テキスト: 「Cognito Identity Pool 一時認証情報発行」

#### バックエンドAPI（.NET Core）

- 右側に配置
- 四角形（色: #512BD4）
- テキスト: 「.NET Core バックエンドAPI」

**ALB**:
- バックエンドAPIの上に配置
- 「Elastic Load Balancing」アイコン

**WAF**:
- ALBの上に配置
- 「WAF」アイコン

#### フロー矢印

1. ユーザー → フロントエンド: 「ログイン画面アクセス」
2. フロントエンド → Cognito User Pool: 「認証リクエスト（MFA）」
3. Cognito User Pool → Lambda: 「Trigger実行」
4. Lambda → DynamoDB: 「ユーザー情報読み書き」
5. Cognito User Pool → フロントエンド: 「JWT トークン」
6. フロントエンド → Cognito Identity Pool: 「トークン交換」
7. Cognito Identity Pool → フロントエンド: 「一時認証情報」
8. フロントエンド → WAF: 「API リクエスト（JWT付き）」
9. WAF → ALB: 「検査通過」
10. ALB → バックエンドAPI: 「リクエスト転送」
11. バックエンドAPI → フロントエンド: 「レスポンス」
12. フロントエンド → ユーザー: 「画面表示」

---

## エクスポート（SVG/PNG）

### SVG エクスポート（レビュー用）

1. draw.io で図を開く
2. 「ファイル」→「エクスポート」→「SVG」
3. 「エクスポート」をクリック
4. ファイル名: `<図の名前>.svg`（例: `システム全体構成図.svg`）
5. 同じディレクトリに保存

### PNG エクスポート（最終版）

1. PM レビュー・ユーザー承認後に実行
2. 「ファイル」→「エクスポート」→「PNG」
3. 「ズーム」: 200%（高解像度）
4. 「透明な背景」: チェックを外す
5. 「エクスポート」をクリック
6. ファイル名: `<図の名前>.png`（例: `システム全体構成図.png`）
7. 同じディレクトリに保存

---

## ベストプラクティス

### 配色

- **本番環境**: #CD2264（赤）
- **ステージング環境**: #147EBA（青）
- **Public Subnet**: #00A4A6（緑青）
- **Private Subnet**: #147EBA（青）
- **Database Subnet**: #C925D1（紫）
- **Transit Gateway**: #8C4FFF（紫）

### レイアウト

- **左から右**: データの流れ
- **上から下**: 階層（Internet → ALB → ECS → RDS）
- **中央にハブ**: Transit Gateway等

### ラベル

- **日本語**: すべてのラベルは日本語
- **明確**: 役割が一目で分かるように
- **パラメータ**: CIDR等の技術詳細も記載

---

**作成日**: 2025-11-07
**作成者**: architect サブエージェント
