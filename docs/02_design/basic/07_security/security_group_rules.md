# セキュリティグループルール詳細

## 目次
1. [本番環境](#本番環境)
2. [ステージング環境](#ステージング環境)
3. [ルール設計原則](#ルール設計原則)
4. [変更手順](#変更手順)

---

## 本番環境

### 1. ALB Security Group

**グループ名**: `kaigo-subsys-prod-alb-sg`
**VPC**: `kaigo-subsys-prod-vpc (10.0.0.0/16)`
**説明**: Application Load Balancer security group

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| HTTPS | TCP | 443 | 0.0.0.0/0 | インターネットからのHTTPSアクセス |
| HTTP | TCP | 80 | 0.0.0.0/0 | HTTPからHTTPSへのリダイレクト |

#### アウトバウンドルール

| タイプ | プロトコル | ポート範囲 | 宛先 | 説明 |
|--------|-----------|-----------|------|------|
| カスタムTCP | TCP | 8080 | `kaigo-subsys-prod-ecs-sg` | ECSタスクへのHTTPトラフィック |

---

### 2. ECS Security Group

**グループ名**: `kaigo-subsys-prod-ecs-sg`
**VPC**: `kaigo-subsys-prod-vpc (10.0.0.0/16)`
**説明**: ECS Fargate tasks security group

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| カスタムTCP | TCP | 8080 | `kaigo-subsys-prod-alb-sg` | ALBからのトラフィック |

#### アウトバウンドルール

| タイプ | プロトコル | ポート範囲 | 宛先 | 説明 |
|--------|-----------|-----------|------|------|
| MySQL | TCP | 3306 | `kaigo-subsys-prod-rds-sg` | RDSへのデータベース接続 |
| カスタムTCP | TCP | 6379 | `kaigo-subsys-prod-elasticache-sg` | ElastiCacheへのRedis接続 |
| NFS | TCP | 2049 | `kaigo-subsys-prod-efs-sg` | EFSへのNFSマウント |
| HTTPS | TCP | 443 | 0.0.0.0/0 | 外部APIアクセス、パッケージダウンロード |
| HTTP | TCP | 80 | 0.0.0.0/0 | 外部APIアクセス（HTTPリダイレクト） |

---

### 3. RDS Security Group

**グループ名**: `kaigo-subsys-prod-rds-sg`
**VPC**: `kaigo-subsys-prod-vpc (10.0.0.0/16)`
**説明**: RDS MySQL security group

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| MySQL | TCP | 3306 | `kaigo-subsys-prod-ecs-sg` | ECSタスクからのデータベース接続 |

#### アウトバウンドルール

なし（デフォルトで全拒否）

---

### 4. ElastiCache Security Group

**グループ名**: `kaigo-subsys-prod-elasticache-sg`
**VPC**: `kaigo-subsys-prod-vpc (10.0.0.0/16)`
**説明**: ElastiCache Redis security group

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| カスタムTCP | TCP | 6379 | `kaigo-subsys-prod-ecs-sg` | ECSタスクからのRedis接続 |

#### アウトバウンドルール

なし（デフォルトで全拒否）

---

### 5. EFS Security Group

**グループ名**: `kaigo-subsys-prod-efs-sg`
**VPC**: `kaigo-subsys-prod-vpc (10.0.0.0/16)`
**説明**: EFS file system security group

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| NFS | TCP | 2049 | `kaigo-subsys-prod-ecs-sg` | ECSタスクからのNFSマウント |

#### アウトバウンドルール

なし（デフォルトで全拒否）

---

### 6. VPC Endpoint Security Group

**グループ名**: `kaigo-subsys-prod-vpce-sg`
**VPC**: `kaigo-subsys-prod-vpc (10.0.0.0/16)`
**説明**: VPC Endpoint security group for S3, ECR, CloudWatch Logs

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| HTTPS | TCP | 443 | `kaigo-subsys-prod-ecs-sg` | ECSタスクからのVPCエンドポイントアクセス |

#### アウトバウンドルール

なし（デフォルトで全拒否）

---

## ステージング環境

### 1. ALB Security Group

**グループ名**: `kaigo-subsys-stg-alb-sg`
**VPC**: `kaigo-subsys-stg-vpc (10.1.0.0/16)`
**説明**: Application Load Balancer security group for staging

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| HTTPS | TCP | 443 | 0.0.0.0/0 | インターネットからのHTTPSアクセス |
| HTTP | TCP | 80 | 0.0.0.0/0 | HTTPからHTTPSへのリダイレクト |

#### アウトバウンドルール

| タイプ | プロトコル | ポート範囲 | 宛先 | 説明 |
|--------|-----------|-----------|------|------|
| カスタムTCP | TCP | 8080 | `kaigo-subsys-stg-ecs-sg` | ECSタスクへのHTTPトラフィック |

---

### 2. ECS Security Group

**グループ名**: `kaigo-subsys-stg-ecs-sg`
**VPC**: `kaigo-subsys-stg-vpc (10.1.0.0/16)`
**説明**: ECS Fargate tasks security group for staging

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| カスタムTCP | TCP | 8080 | `kaigo-subsys-stg-alb-sg` | ALBからのトラフィック |

#### アウトバウンドルール

| タイプ | プロトコル | ポート範囲 | 宛先 | 説明 |
|--------|-----------|-----------|------|------|
| MySQL | TCP | 3306 | `kaigo-subsys-stg-rds-sg` | RDSへのデータベース接続 |
| カスタムTCP | TCP | 6379 | `kaigo-subsys-stg-elasticache-sg` | ElastiCacheへのRedis接続 |
| NFS | TCP | 2049 | `kaigo-subsys-stg-efs-sg` | EFSへのNFSマウント |
| HTTPS | TCP | 443 | 0.0.0.0/0 | 外部APIアクセス、パッケージダウンロード |
| HTTP | TCP | 80 | 0.0.0.0/0 | 外部APIアクセス（HTTPリダイレクト） |

---

### 3. RDS Security Group

**グループ名**: `kaigo-subsys-stg-rds-sg`
**VPC**: `kaigo-subsys-stg-vpc (10.1.0.0/16)`
**説明**: RDS MySQL security group for staging

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| MySQL | TCP | 3306 | `kaigo-subsys-stg-ecs-sg` | ECSタスクからのデータベース接続 |

#### アウトバウンドルール

なし（デフォルトで全拒否）

---

### 4. ElastiCache Security Group

**グループ名**: `kaigo-subsys-stg-elasticache-sg`
**VPC**: `kaigo-subsys-stg-vpc (10.1.0.0/16)`
**説明**: ElastiCache Redis security group for staging

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| カスタムTCP | TCP | 6379 | `kaigo-subsys-stg-ecs-sg` | ECSタスクからのRedis接続 |

#### アウトバウンドルール

なし（デフォルトで全拒否）

---

### 5. EFS Security Group

**グループ名**: `kaigo-subsys-stg-efs-sg`
**VPC**: `kaigo-subsys-stg-vpc (10.1.0.0/16)`
**説明**: EFS file system security group for staging

#### インバウンドルール

| タイプ | プロトコル | ポート範囲 | ソース | 説明 |
|--------|-----------|-----------|--------|------|
| NFS | TCP | 2049 | `kaigo-subsys-stg-ecs-sg` | ECSタスクからのNFSマウント |

#### アウトバウンドルール

なし（デフォルトで全拒否）

---

## ルール設計原則

### 1. 最小権限の原則

- 必要最小限のポートのみ開放
- ソースは必ずセキュリティグループIDまたは特定のCIDRブロックを指定
- 0.0.0.0/0 は ALB のインバウンドのみ許可

### 2. デフォルト拒否

- アウトバウンドルールは必要なもののみ明示的に許可
- データベース、キャッシュ、EFSはアウトバウンド不要

### 3. セキュリティグループの参照

- ソース/宛先にセキュリティグループIDを使用
- IPアドレスの指定は避ける（変更追従が困難）

### 4. 環境分離

- 本番環境とステージング環境でセキュリティグループを完全に分離
- クロス環境のアクセスは不可

### 5. 命名規則

```
<project>-<environment>-<service>-sg
```

例: `kaigo-subsys-prod-ecs-sg`

---

## 変更手順

### セキュリティグループルールの追加

#### 1. 変更申請

- 変更内容、理由、影響範囲を記載
- セキュリティチームのレビュー

#### 2. CloudFormationテンプレート更新

```yaml
ECSSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupName: kaigo-subsys-prod-ecs-sg
    GroupDescription: ECS Fargate tasks security group
    VpcId: !Ref VPC
    SecurityGroupIngress:
      - IpProtocol: tcp
        FromPort: 8080
        ToPort: 8080
        SourceSecurityGroupId: !Ref ALBSecurityGroup
        Description: "ALB traffic"
    SecurityGroupEgress:
      - IpProtocol: tcp
        FromPort: 3306
        ToPort: 3306
        DestinationSecurityGroupId: !Ref RDSSecurityGroup
        Description: "RDS connection"
      - IpProtocol: tcp
        FromPort: 6379
        ToPort: 6379
        DestinationSecurityGroupId: !Ref ElastiCacheSecurityGroup
        Description: "ElastiCache connection"
      - IpProtocol: tcp
        FromPort: 2049
        ToPort: 2049
        DestinationSecurityGroupId: !Ref EFSSecurityGroup
        Description: "EFS mount"
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 0.0.0.0/0
        Description: "External API access"
    Tags:
      - Key: Name
        Value: kaigo-subsys-prod-ecs-sg
      - Key: Environment
        Value: production
```

#### 3. ステージング環境で検証

```bash
# CloudFormation スタック更新（ステージング）
aws cloudformation update-stack \
  --stack-name kaigo-subsys-stg-security-groups \
  --template-body file://security-groups.yaml \
  --parameters ParameterKey=Environment,ParameterValue=staging
```

#### 4. 本番環境へデプロイ

```bash
# CloudFormation スタック更新（本番）
aws cloudformation update-stack \
  --stack-name kaigo-subsys-prod-security-groups \
  --template-body file://security-groups.yaml \
  --parameters ParameterKey=Environment,ParameterValue=production
```

#### 5. 動作確認

- アプリケーションの動作確認
- VPC Flow Logs で通信ログ確認
- セキュリティグループのルールが正しく適用されているか確認

---

## トラブルシューティング

### 接続できない場合

#### 1. セキュリティグループルールの確認

```bash
# セキュリティグループのルール確認
aws ec2 describe-security-groups \
  --group-names kaigo-subsys-prod-ecs-sg \
  --query "SecurityGroups[*].{Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}"
```

#### 2. VPC Flow Logs の確認

```bash
# CloudWatch Logs でフロー拒否ログを検索
aws logs filter-log-events \
  --log-group-name /aws/vpc/flowlogs \
  --filter-pattern '[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action="REJECT", flowlogstatus]'
```

#### 3. ネットワーク到達性の確認

- VPC Reachability Analyzer を使用
- ソースからターゲットへのパスを分析

---

## セキュリティグループ監査

### 定期監査項目

| 項目 | チェック内容 | 頻度 |
|------|------------|------|
| 0.0.0.0/0 の使用 | ALB 以外で使用されていないか | 月次 |
| 未使用ルール | 不要なルールが残っていないか | 四半期 |
| ドキュメント整合性 | ドキュメントと実際のルールが一致しているか | 四半期 |
| 変更履歴 | 承認されていない変更がないか | 月次 |

### 監査コマンド

```bash
# すべてのセキュリティグループをエクスポート
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-xxxxx" \
  --query "SecurityGroups[*].[GroupId,GroupName,IpPermissions,IpPermissionsEgress]" \
  --output json > security-groups-audit.json
```

---

## 関連ドキュメント

- [セキュリティ設計](./security_design.md)
- [ネットワーク設計](../03_network/network_design.md)
- [VPC設計](../03_network/vpc_design.md)

---

**作成日**: 2025-11-05
**作成者**: Architect
**バージョン**: 1.0
