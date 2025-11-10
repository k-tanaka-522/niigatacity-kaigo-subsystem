# マルチアカウント対応CloudFormation構成 - SREレビュー

**レビュー日**: 2025-11-10
**レビュアー**: Claude (sre サブエージェント)
**対象**: infra-architect提案「Option B: 機能別スタック + パラメータ制御」
**ステータス**: ⚠️ 条件付き承認

---

## 📋 エグゼクティブサマリー

### 総合評価: ⚠️ 条件付き承認

**結論**: Option B（機能別スタック + パラメータ制御）は運用面で実現可能だが、**以下の条件を満たす必要がある**:

1. **TGW ID自動取得スクリプトの実装**（推奨）
2. **マルチアカウントロールバック手順の明文化**（必須）
3. **クロスアカウント監視の設計**（必須）
4. **dev/staging環境のコスト最適化戦略の決定**（推奨）
5. **IAMロール設計のセキュリティレビュー**（必須）

### 主要な懸念事項

| 懸念事項 | 重大度 | 影響範囲 | 対応状況 |
|---------|--------|---------|---------|
| TGW ID手動設定のヒューマンエラーリスク | 🟡 Medium | production環境 | 未対応 |
| マルチアカウントロールバック手順の未定義 | 🔴 High | 障害復旧 | 未対応 |
| クロスアカウント監視の設計漏れ | 🔴 High | 運用性 | 未対応 |
| dev/staging環境の構成差異リスク | 🟡 Medium | コスト vs 一貫性 | 未決定 |
| クロスアカウント権限設計の責任分担不明確 | 🟡 Medium | セキュリティ | 未対応 |

---

## 1. infra-architect提案への回答

### Q1: TGW ID自動取得スクリプト

**回答**: ✅ **自動化を強く推奨**

#### 推奨方法: `scripts/deploy-multi-account.sh` 作成

**理由**:
- ✅ ヒューマンエラーの排除（手動でTGW IDをコピペするリスク）
- ✅ 再現性の確保（誰がデプロイしても同じ結果）
- ✅ 運用負荷の削減（デプロイ時間の短縮）

**実装案**:

```bash
#!/bin/bash
# scripts/deploy-multi-account.sh

ENVIRONMENT=$1

# 1. Common Account にデプロイ（TGW作成）
export AWS_PROFILE=niigata-kaigo-${ENVIRONMENT}-common
./scripts/deploy-phase.sh ${ENVIRONMENT} phase1-common

# 2. TGW IDを自動取得
TGW_ID=$(aws ec2 describe-transit-gateways \
  --filters "Name=tag:Environment,Values=${ENVIRONMENT}" \
  --query 'TransitGateways[0].TransitGatewayId' \
  --output text \
  --region ap-northeast-1)

if [ -z "$TGW_ID" ]; then
  echo "ERROR: TGW ID not found"
  exit 1
fi

echo "TGW ID: $TGW_ID"

# 3. パラメータファイルに自動注入
jq ".[] |= if .ParameterKey == \"TransitGatewayId\" then .ParameterValue = \"$TGW_ID\" else . end" \
  parameters/${ENVIRONMENT}/app-account.json > parameters/${ENVIRONMENT}/app-account.json.tmp
mv parameters/${ENVIRONMENT}/app-account.json.tmp parameters/${ENVIRONMENT}/app-account.json

# 4. App Account にデプロイ
export AWS_PROFILE=niigata-kaigo-${ENVIRONMENT}-app
./scripts/deploy-phase.sh ${ENVIRONMENT} phase1-app
```

**メリット**:
- 手動設定なし
- 監査証跡（スクリプト実行ログでTGW ID取得を記録）
- GitHub Actionsとの統合が容易

**デメリット**:
- スクリプトの複雑化（軽微）
- AWS CLI依存（既存環境で問題なし）

---

### Q2: ロールバック戦略

**回答**: ✅ **App Account → Common Account の逆順**

#### ロールバック順序（依存関係の逆順）

**原則**: デプロイの逆順 = 依存関係の破壊を最小化

**具体的な手順**:

```bash
# ロールバックシナリオ: production環境で障害発生

# ステップ1: App Account のスタックをロールバック
export AWS_PROFILE=niigata-kaigo-production-app
./scripts/rollback.sh production 03_network app-vpc-stack

# ステップ2: Common Account のスタックをロールバック
export AWS_PROFILE=niigata-kaigo-production-common
./scripts/rollback.sh production 02_network transit-gateway-stack
./scripts/rollback.sh production 02_network common-vpc-stack
```

#### マルチアカウントロールバックスクリプトの作成

**scripts/rollback-multi-account.sh**:

```bash
#!/bin/bash
# マルチアカウント対応ロールバック

ENVIRONMENT=$1

# 1. App Account ロールバック
export AWS_PROFILE=niigata-kaigo-${ENVIRONMENT}-app
./scripts/rollback.sh ${ENVIRONMENT} 03_network app-vpc-stack

# 2. 依存関係チェック（App VPC削除完了を確認）
aws cloudformation wait stack-delete-complete \
  --stack-name niigata-kaigo-${ENVIRONMENT}-app-vpc-stack \
  --region ap-northeast-1

# 3. Common Account ロールバック
export AWS_PROFILE=niigata-kaigo-${ENVIRONMENT}-common
./scripts/rollback.sh ${ENVIRONMENT} 02_network transit-gateway-stack
./scripts/rollback.sh ${ENVIRONMENT} 02_network common-vpc-stack
```

**Change Setsとの連携**:
- ロールバック前に Change Set で変更内容を確認（dry-run）
- ロールバック = 「前のテンプレートで Change Set作成 → 実行」

---

### Q3: 監視・アラート設計

**回答**: ✅ **Common Account で集約監視 + App Account で個別監視**

#### 推奨構成: ハイブリッド監視

**1. Transit Gateway監視: Common Account**

**理由**:
- TGWリソースは Common Account に配置
- CloudWatchメトリクスは同一アカウント内で取得が効率的

**具体的な設計**:

```yaml
# templates/monitoring/cloudwatch-alarms-tgw.yaml

Resources:
  TransitGatewayBytesInAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub ${ProjectName}-${Environment}-tgw-bytes-in-high
      MetricName: BytesIn
      Namespace: AWS/TransitGateway
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 10000000000  # 10GB/5分
      Dimensions:
        - Name: TransitGateway
          Value: !Ref TransitGateway
      AlarmActions:
        - !Ref SNSTopicArn  # Common Account の SNS Topic

  TransitGatewayPacketDropCountAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub ${ProjectName}-${Environment}-tgw-packet-drop
      MetricName: PacketDropCountBlackhole
      Namespace: AWS/TransitGateway
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 100
      TreatMissingData: notBreaching
      Dimensions:
        - Name: TransitGateway
          Value: !Ref TransitGateway
      AlarmActions:
        - !Ref SNSTopicArn
```

**2. App VPC監視: App Account**

**理由**:
- App VPCリソース（ECS, RDS, ALB）は App Account に配置
- アプリケーションメトリクスとの関連性

**具体的な設計**:

```yaml
# templates/monitoring/cloudwatch-alarms-app.yaml

Resources:
  VPCFlowLogsAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub ${ProjectName}-${Environment}-vpc-flow-logs-error
      MetricName: ErrorCount
      Namespace: AWS/VPC
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 10
```

**3. クロスアカウント通知: Common Account SNS → App Account Lambda**

**SNS Topic共有（AWS RAM不使用、SNS Policyで対応）**:

```json
// Common Account の SNS Topic Policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${AppAccountId}:root"
      },
      "Action": "SNS:Subscribe",
      "Resource": "arn:aws:sns:ap-northeast-1:${CommonAccountId}:niigata-kaigo-alerts"
    }
  ]
}
```

**App Account の Lambda で受信**:

```bash
# App Account で Common Account の SNS にサブスクライブ
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-northeast-1:${CommonAccountId}:niigata-kaigo-alerts \
  --protocol lambda \
  --notification-endpoint arn:aws:lambda:ap-northeast-1:${AppAccountId}:function:alert-handler \
  --region ap-northeast-1
```

---

### Q4: dev/staging環境のコスト削減

**回答**: ⚠️ **VPC Peering で代替（条件付き推奨）**

#### 推奨: dev環境はVPC Peering、staging環境はTGW

**理由**:
- **dev環境**: 開発者の検証環境、本番構成との完全一致は不要
- **staging環境**: 本番前の最終検証、本番構成と同一であるべき

#### コスト比較（詳細版）

| 項目 | dev（VPC Peering） | staging（TGW） | production（TGW） |
|-----|------------------|---------------|------------------|
| Transit Gateway | $0 | $36/月 | $36/月 |
| VPC Peering | $0 | $0 | $0 |
| データ転送（AZ内） | $0.01/GB | $0.02/GB | $0.02/GB |
| データ転送（クロスAZ） | $0.01/GB | $0.02/GB | $0.02/GB |
| **合計（月額）** | **$5/月** | **$41/月** | **$41/月** |
| **年間コスト** | **$60** | **$492** | **$492** |

**削減効果**: dev環境でVPC Peering使用により **$36/月 = $432/年** のコスト削減

#### 構成差異リスクの評価

**リスク**: dev環境とproduction環境の構成が異なる

**対策**:
1. **staging環境で本番構成を完全再現**（TGW使用）
2. **dev環境でのTGW動作確認はCI/CDパイプラインでstaging環境にデプロイして検証**
3. **インフラテストコード（Terratest/InSpec）で構成差異を検出**

**判断基準**:

| 項目 | VPC Peering | TGW |
|-----|------------|-----|
| コスト削減効果 | 🟢 高い（$36/月） | 🔴 なし |
| 本番環境との一貫性 | 🔴 低い | 🟢 高い |
| 運用複雑性 | 🟢 低い（Peering設定のみ） | 🟡 中程度（TGW設定） |
| スケーラビリティ | 🔴 低い（Peering数に上限） | 🟢 高い（TGW 1つで複数VPC接続） |

**推奨**: プロジェクト予算と本番環境の一貫性要件に応じて判断

- **予算重視**: dev環境はVPC Peering
- **一貫性重視**: dev環境もTGW（ただしコスト増）

---

### Q5: クロスアカウント権限

**回答**: ✅ **infra-architect + sre が設計、security-engineer がレビュー**

#### 責任分担

| 役割 | 担当 | タスク |
|-----|------|--------|
| **IAMロール設計** | infra-architect + sre | クロスアカウントアクセスのIAMロール・ポリシー設計 |
| **セキュリティレビュー** | security-engineer（または外部監査） | 最小権限原則の確認、脆弱性チェック |
| **実装** | sre | CloudFormationテンプレート作成 |
| **承認** | PM + security-engineer | 本番環境への適用承認 |

#### 必要な権限の洗い出し

**Common Account → App Account**:

```json
// Common Account の IAM Role
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeTransitGateways",
        "ec2:DescribeTransitGatewayAttachments",
        "ec2:AcceptTransitGatewayVpcAttachment"
      ],
      "Resource": "*"
    }
  ]
}
```

**App Account → Common Account**:

```json
// App Account の IAM Role
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTransitGatewayVpcAttachment",
        "ec2:DeleteTransitGatewayVpcAttachment",
        "ec2:ModifyTransitGatewayVpcAttachment"
      ],
      "Resource": [
        "arn:aws:ec2:*:${CommonAccountId}:transit-gateway/*",
        "arn:aws:ec2:*:${AppAccountId}:vpc/*"
      ]
    }
  ]
}
```

**信頼関係**:

```json
// App Account IAM Role の信頼関係
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${CommonAccountId}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${UniqueExternalId}"
        }
      }
    }
  ]
}
```

**セキュリティレビューポイント**:
- [ ] 最小権限原則（必要最低限の権限のみ）
- [ ] ExternalIdの使用（CSRF攻撃対策）
- [ ] リソースARNの限定（ワイルドカード使用の最小化）
- [ ] MFA必須化（本番環境の手動操作）
- [ ] CloudTrailでクロスアカウントアクセスをログ記録

---

## 2. 運用面の追加評価

### 2.1 デプロイ自動化

#### GitHub Actionsワークフロー評価

**現在の提案（環境変数切り替え方式）**:

```yaml
env:
  AWS_ACCOUNT_COMMON: ${{ secrets.AWS_ACCOUNT_COMMON }}
  AWS_ACCOUNT_APP: ${{ secrets.AWS_ACCOUNT_APP }}

jobs:
  deploy-common:
    steps:
      - name: Assume Common Account Role
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_COMMON }}:role/GitHubActionsRole
      - run: ./scripts/deploy-phase.sh production phase1-common

  deploy-app:
    needs: deploy-common
    steps:
      - name: Assume App Account Role
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_APP }}:role/GitHubActionsRole
      - run: ./scripts/deploy-phase.sh production phase1-app
```

**評価**: ✅ **運用可能、改善提案あり**

**改善提案**:

1. **TGW ID受け渡しの自動化**:

```yaml
  deploy-common:
    outputs:
      tgw-id: ${{ steps.get-tgw-id.outputs.tgw-id }}
    steps:
      - id: get-tgw-id
        run: |
          TGW_ID=$(aws ec2 describe-transit-gateways \
            --filters "Name=tag:Environment,Values=production" \
            --query 'TransitGateways[0].TransitGatewayId' \
            --output text)
          echo "tgw-id=$TGW_ID" >> $GITHUB_OUTPUT

  deploy-app:
    needs: deploy-common
    steps:
      - name: Update parameters with TGW ID
        run: |
          jq ".[] |= if .ParameterKey == \"TransitGatewayId\" then .ParameterValue = \"${{ needs.deploy-common.outputs.tgw-id }}\" else . end" \
            parameters/production/app-account.json > parameters/production/app-account.json.tmp
          mv parameters/production/app-account.json.tmp parameters/production/app-account.json
```

2. **失敗時の自動ロールバック**:

```yaml
  deploy-app:
    steps:
      - run: ./scripts/deploy-phase.sh production phase1-app
        id: deploy
      - if: failure()
        run: ./scripts/rollback-multi-account.sh production
```

3. **デプロイ完了通知**:

```yaml
  notify:
    needs: [deploy-common, deploy-app]
    if: always()
    steps:
      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Multi-Account Deploy: ${{ job.status }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "Environment: production\nStatus: ${{ job.status }}"
                  }
                }
              ]
            }
```

---

### 2.2 障害時の復旧手順

#### シナリオ1: Transit Gateway障害時

**検知**:
- CloudWatch Alarm: `PacketDropCountBlackhole` 閾値超過
- アラート: Common Account SNS → App Account Lambda → Slack

**影響範囲**:
- Common VPC ⇄ App VPC 間の通信が停止
- アプリケーション: Direct Connect経由のオンプレミス通信が不可

**復旧手順**:

```bash
# 1. TGWステータス確認
aws ec2 describe-transit-gateways \
  --transit-gateway-ids tgw-xxxxx \
  --region ap-northeast-1

# 2. アタッチメント確認
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=tgw-xxxxx" \
  --region ap-northeast-1

# 3. ロールバック（前のバージョンにロールバック）
export AWS_PROFILE=niigata-kaigo-production-common
./scripts/rollback.sh production 02_network transit-gateway-stack

# 4. 復旧確認
aws ec2 describe-transit-gateway-attachments --region ap-northeast-1
```

**RTO**: 30分
**RPO**: 0（TGW設定は状態を持たない）

---

#### シナリオ2: Common VPC障害時

**検知**:
- CloudWatch Alarm: VPCエンドポイント接続エラー
- アラート: Common Account SNS

**影響範囲**:
- Common VPC内のリソース（VPCエンドポイント等）が停止
- 監査ログ（CloudTrail S3エンドポイント経由）の記録が停止

**復旧手順**:

```bash
# 1. VPCステータス確認
aws ec2 describe-vpcs \
  --vpc-ids vpc-xxxxx \
  --region ap-northeast-1

# 2. ロールバック
export AWS_PROFILE=niigata-kaigo-production-common
./scripts/rollback.sh production 02_network common-vpc-stack

# 3. 復旧確認
aws ec2 describe-vpcs --region ap-northeast-1
```

**RTO**: 20分
**RPO**: 0（VPC設定は状態を持たない）

---

#### シナリオ3: App VPC障害時

**検知**:
- CloudWatch Alarm: ECS Unhealthy Target Count
- アラート: App Account SNS

**影響範囲**:
- アプリケーション全停止
- ユーザーへの影響: 大

**復旧手順**:

```bash
# 1. VPCステータス確認
export AWS_PROFILE=niigata-kaigo-production-app
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx --region ap-northeast-1

# 2. ECS/RDSへの影響確認
aws ecs describe-services --cluster niigata-kaigo-production-ecs-cluster --region ap-northeast-1
aws rds describe-db-instances --db-instance-identifier niigata-kaigo-production-mysql --region ap-northeast-1

# 3. ロールバック
./scripts/rollback.sh production 03_network app-vpc-stack

# 4. アプリケーション復旧確認
curl https://api.niigata-kaigo.example.com/health
```

**RTO**: 40分（RDS再起動時間含む）
**RPO**: 1時間（RDS自動バックアップ）

---

### 2.3 段階的移行のリスク

#### 現在の`stacks/02-network/main.yaml`から新構成への移行

**現状**: シングルアカウント構成

```
stacks/02-network/main.yaml
  ├─ VPC（10.2.0.0/16 staging、10.1.0.0/16 production）
  ├─ Subnets
  ├─ NAT Gateways
  └─ Route Tables
```

**移行後**: マルチアカウント構成

```
stacks/02-network-common/main.yaml（Common Account）
  ├─ Common VPC（10.1.0.0/16）
  ├─ Transit Gateway
  └─ VPC Endpoints

stacks/03-network-app/main.yaml（App Account）
  ├─ App VPC（10.3.0.0/16）
  ├─ TGW Attachment
  └─ Route Tables（TGW経由ルート追加）
```

#### 移行中のダウンタイムリスク

**リスク評価**:

| 移行ステップ | ダウンタイムリスク | 対策 |
|------------|-----------------|------|
| Common Account VPC作成 | 🟢 なし | 並行稼働（既存VPCと独立） |
| Transit Gateway作成 | 🟢 なし | 既存VPCに影響なし |
| App Account VPC作成 | 🟢 なし | 並行稼働 |
| TGW Attachment作成 | 🟢 なし | 既存VPCに影響なし |
| Route Table変更（TGW経由ルート追加） | 🔴 あり | **Blue-Green方式** |
| 旧VPC削除 | 🔴 あり | **トラフィック完全移行後** |

**ダウンタイム最小化戦略**: Blue-Green デプロイ

#### 推奨する移行手順（Blue-Green方式）

**Phase A: 新環境構築（Blue環境）**

```bash
# 1. Common Account に新VPC + TGW作成（並行稼働）
export AWS_PROFILE=niigata-kaigo-production-common
./scripts/deploy-phase.sh production phase1-common

# 2. App Account に新VPC作成（並行稼働）
export AWS_PROFILE=niigata-kaigo-production-app
./scripts/deploy-phase.sh production phase1-app

# 3. 新VPCにアプリケーションデプロイ（テスト環境）
./scripts/deploy-phase.sh production phase2-app  # RDS
./scripts/deploy-phase.sh production phase3-app  # ECS
```

**Phase B: トラフィック切り替え（Green → Blue）**

```bash
# 4. Route53 Weighted Routing（10%トラフィックを新環境へ）
aws route53 change-resource-record-sets \
  --hosted-zone-id Z00357372MZ0LWBMNTA9X \
  --change-batch file://weighted-routing-10.json

# 5. 監視（1時間）
# CloudWatch メトリクス、エラーログ確認

# 6. ウェイトを100%に変更
aws route53 change-resource-record-sets \
  --hosted-zone-id Z00357372MZ0LWBMNTA9X \
  --change-batch file://weighted-routing-100.json
```

**Phase C: 旧環境削除**

```bash
# 7. トラフィックが新環境に完全移行したことを確認（24時間監視）

# 8. 旧VPCスタック削除
export AWS_PROFILE=old-single-account
./scripts/delete-all-stacks.sh production
```

**ダウンタイム**: 0秒（理論値）
**ロールバック時間**: 5分（Route53レコード変更のみ）

#### ロールバックプラン

**トリガー**: 新環境でエラー率が1%を超えた場合

**手順**:

```bash
# 1. Route53 ウェイトを0%に変更（旧環境100%に戻す）
aws route53 change-resource-record-sets \
  --hosted-zone-id Z00357372MZ0LWBMNTA9X \
  --change-batch file://weighted-routing-rollback.json

# 2. 新環境のトラブルシューティング
# CloudWatch Logs、ECSタスク状態確認

# 3. 原因修正後、再度切り替え
```

**ロールバック時間**: 5分

---

### 2.4 運用コスト

#### 人的コスト評価

**マルチアカウント管理の運用負荷**:

| 運用タスク | シングルアカウント | マルチアカウント | 増加工数 |
|-----------|------------------|-----------------|---------|
| デプロイ作業 | 1時間/週 | 1.5時間/週 | +0.5時間 |
| 監視・アラート対応 | 2時間/週 | 3時間/週 | +1時間 |
| IAMロール管理 | 0.5時間/週 | 1時間/週 | +0.5時間 |
| コスト最適化 | 1時間/月 | 2時間/月 | +1時間 |
| 障害対応訓練 | 2時間/月 | 4時間/月 | +2時間 |
| **合計（月間）** | **約20時間** | **約30時間** | **+10時間** |

**人件費換算**:
- エンジニア時給: 5,000円（仮定）
- 追加工数: 10時間/月
- **追加人件費: 50,000円/月 = 600,000円/年**

**単一アカウント構成と比較した運用コスト増**:

| コスト項目 | シングル | マルチ | 差分 |
|-----------|---------|-------|------|
| インフラコスト | $49/月 | $188/月 | +$139/月（約20,000円） |
| 人件費 | 100,000円/月 | 150,000円/月 | +50,000円/月 |
| **合計（月額）** | **約105,000円** | **約180,000円** | **+75,000円** |
| **年間コスト** | **約1,260,000円** | **約2,160,000円** | **+900,000円** |

**コスト増の正当性**:
- ✅ GCAS準拠強化（監査対応コスト削減）
- ✅ セキュリティインシデント防止（損害額の削減）
- ✅ スケーラビリティ向上（将来の拡張コスト削減）

**コスト削減策**:
1. dev環境でVPC Peering使用（$432/年削減）
2. staging環境の夜間停止（NAT Gateway停止で$15/月削減）
3. CloudWatch Logsの保持期間最適化（$5/月削減）

**最終的な追加コスト**: 約 **750,000円/年**

---

## 3. 総合評価

### ✅ 承認ポイント

#### infra-architect提案で問題ない点

1. ✅ **Option B（機能別スタック + パラメータ制御）は運用可能**
   - stacks/02-network-common/ と stacks/03-network-app/ に分割
   - パラメータファイルでアカウントIDを制御
   - 既存のスクリプト（deploy.sh, rollback.sh）を流用可能

2. ✅ **TGW共有方式（パラメータ渡し）は実装が容易**
   - AWS RAM不使用でシンプル
   - CloudFormation Outputsで渡す設計が明確

3. ✅ **段階的移行が可能**
   - dev → staging → production の順番でリスク最小化
   - Blue-Green方式でダウンタイム0を実現可能

4. ✅ **既存の技術標準に準拠**
   - `.claude/docs/40_standards/42_infra/iac/cloudformation.md` に適合
   - Change Sets必須の原則を維持

---

### ⚠️ 懸念事項

#### 運用上の懸念点

1. ⚠️ **TGW ID手動設定のヒューマンエラーリスク**
   - **影響**: production環境でのネットワーク障害
   - **発生確率**: 低〜中（手順書があれば低減）
   - **対策**: 自動化スクリプト実装（Q1回答参照）

2. ⚠️ **マルチアカウントロールバック手順の未定義**
   - **影響**: 障害時の復旧時間延長（RTO増加）
   - **発生確率**: 高（障害は必ず発生する前提）
   - **対策**: `scripts/rollback-multi-account.sh` 実装（Q2回答参照）

3. ⚠️ **クロスアカウント監視の設計漏れ**
   - **影響**: 障害の早期検知不可、インシデント対応遅延
   - **発生確率**: 高（監視なしでは気づけない）
   - **対策**: Common Account集約監視 + App Account個別監視（Q3回答参照）

4. ⚠️ **dev/staging環境の構成差異リスク**
   - **影響**: stagingで検証した内容がproductionで再現しない
   - **発生確率**: 中（VPC Peering vs TGWの差異）
   - **対策**: stagingはTGW必須、devはVPC Peering可（Q4回答参照）

5. ⚠️ **運用コスト増（+75,000円/月）**
   - **影響**: プロジェクト予算圧迫
   - **発生確率**: 高（確実に発生）
   - **対策**: コスト削減策実施、GCAS準拠のメリットで正当化

---

### 💡 改善提案

#### より良い運用のための提案

#### 1. TGW ID自動取得スクリプトの実装（必須）

**優先度**: 🔴 High

**実装内容**:
- `scripts/deploy-multi-account.sh` 作成（Q1回答参照）
- GitHub Actions統合（outputs機能でTGW ID受け渡し）

**期待効果**:
- ヒューマンエラー排除
- デプロイ時間短縮（5分 → 3分）

---

#### 2. マルチアカウントロールバックスクリプトの実装（必須）

**優先度**: 🔴 High

**実装内容**:
- `scripts/rollback-multi-account.sh` 作成（Q2回答参照）
- 依存関係チェック機能追加
- ロールバックテストの定期実施（月1回）

**期待効果**:
- RTO短縮（60分 → 30分）
- 運用負荷削減（手順書確認時間削減）

---

#### 3. クロスアカウント監視の実装（必須）

**優先度**: 🔴 High

**実装内容**:
- Common Account: TGW監視アラーム（Q3回答参照）
- App Account: VPC/ECS/RDS監視アラーム
- SNS Topic共有（Common → App）
- Slack通知統合

**期待効果**:
- MTTR短縮（平均復旧時間）
- インシデント早期検知

---

#### 4. コスト最適化戦略の実装（推奨）

**優先度**: 🟡 Medium

**実装内容**:
- dev環境: VPC Peering使用（$432/年削減）
- staging環境: 夜間停止（$180/年削減）
- CloudWatch Logs保持期間最適化（$60/年削減）

**期待効果**:
- 年間コスト削減: $672（約96,000円）

---

#### 5. インフラテストコードの実装（推奨）

**優先度**: 🟡 Medium

**実装内容**:
- Terratest/InSpecでインフラ構成テスト
- CI/CDパイプラインに統合
- dev vs staging vs production の構成差異検出

**期待効果**:
- 構成ドリフト検出
- 本番環境デプロイ前の品質保証

---

#### 6. IAMロール設計のセキュリティレビュー（必須）

**優先度**: 🔴 High

**実装内容**:
- クロスアカウントIAMロール設計（Q5回答参照）
- security-engineerレビュー
- 最小権限原則の適用確認

**期待効果**:
- セキュリティリスク低減
- GCAS監査対応

---

## 4. 推奨デプロイ手順（最終版）

### 4.1 dev環境での検証手順

**前提条件**:
- [ ] AWS Organizations セットアップ完了
- [ ] dev-common, dev-app アカウント作成完了
- [ ] IAMロール作成完了

**手順**:

```bash
# 1. スクリプト実装
cd infra/cloudformation/scripts
# - deploy-multi-account.sh 作成
# - rollback-multi-account.sh 作成

# 2. dev-common にデプロイ
export AWS_PROFILE=niigata-kaigo-dev-common
./deploy-multi-account.sh dev

# 3. 検証
# - TGW ID が自動取得されているか確認
# - Common VPC と App VPC 間の通信確認

# 4. ロールバックテスト
./rollback-multi-account.sh dev

# 5. 再デプロイ確認
./deploy-multi-account.sh dev
```

**検証項目**:
- [ ] TGW ID自動取得が動作
- [ ] Common VPC → App VPC 通信が成功
- [ ] ロールバックが成功
- [ ] 再デプロイが成功

**所要時間**: 2時間

---

### 4.2 staging環境での本番同等検証

**前提条件**:
- [ ] dev環境での検証完了
- [ ] staging-common, staging-app アカウント作成完了

**手順**:

```bash
# 1. staging-common にデプロイ
export AWS_PROFILE=niigata-kaigo-staging-common
./deploy-multi-account.sh staging

# 2. 監視アラーム確認
# CloudWatch Alarms が正常に設定されているか

# 3. 負荷テスト（本番相当）
# JMeterで100同時接続テスト

# 4. 障害シミュレーション
# - TGW障害シミュレーション
# - Common VPC障害シミュレーション
# - App VPC障害シミュレーション

# 5. ロールバックテスト
./rollback-multi-account.sh staging
```

**検証項目**:
- [ ] 本番相当の負荷テストが成功
- [ ] 監視アラームが正常に動作
- [ ] 障害シミュレーションで復旧手順が動作
- [ ] ロールバックが30分以内に完了

**所要時間**: 1日

---

### 4.3 production環境での本番デプロイ手順

**前提条件**:
- [ ] staging環境での検証完了
- [ ] production-common, production-app アカウント作成完了
- [ ] 本番デプロイ承認取得（PM + security-engineer）

**デプロイ実施時間**: 深夜1:00〜5:00（メンテナンス時間）

**手順**:

```bash
# Phase 1: 新環境構築（並行稼働）
# 1. production-common にデプロイ
export AWS_PROFILE=niigata-kaigo-production-common
./deploy-multi-account.sh production  # TGW + Common VPC作成

# 2. production-app にデプロイ
export AWS_PROFILE=niigata-kaigo-production-app
./deploy-phase.sh production phase1-app  # App VPC作成
./deploy-phase.sh production phase2-app  # RDS作成
./deploy-phase.sh production phase3-app  # ECS作成

# 3. データ移行
# RDSスナップショットから復元
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier niigata-kaigo-production-mysql \
  --db-snapshot-identifier migration-snapshot-20250110

# Phase 2: トラフィック切り替え（Blue-Green）
# 4. Route53 Weighted Routing（10%）
aws route53 change-resource-record-sets \
  --hosted-zone-id Z00357372MZ0LWBMNTA9X \
  --change-batch file://weighted-routing-10.json

# 5. 監視（30分）
# CloudWatch メトリクス、エラーログ確認

# 6. ウェイトを100%に変更
aws route53 change-resource-record-sets \
  --hosted-zone-id Z00357372MZ0LWBMNTA9X \
  --change-batch file://weighted-routing-100.json

# 7. 旧環境監視（24時間）
# トラフィックが0になったことを確認

# Phase 3: 旧環境削除
# 8. 旧VPCスタック削除（1週間後）
export AWS_PROFILE=old-single-account
./delete-all-stacks.sh production
```

**チェックリスト**:
- [ ] 事前バックアップ取得完了
- [ ] ロールバック手順確認済み
- [ ] 監視アラーム動作確認済み
- [ ] Slack通知テスト完了
- [ ] インシデント対応チーム待機
- [ ] メンテナンス通知送信済み

**想定所要時間**:
- Phase 1: 2時間
- Phase 2: 1時間
- Phase 3: 30分（1週間後）

**ロールバック判断基準**:
- エラー率が1%を超えた場合
- RTO 40分を超えた場合

---

## 5. 次のアクション

### 即座に実施

1. **TGW ID自動取得スクリプト実装**
   - 担当: sre
   - 期限: 2営業日以内
   - 成果物: `scripts/deploy-multi-account.sh`

2. **マルチアカウントロールバックスクリプト実装**
   - 担当: sre
   - 期限: 2営業日以内
   - 成果物: `scripts/rollback-multi-account.sh`

3. **クロスアカウント監視設計**
   - 担当: sre
   - 期限: 3営業日以内
   - 成果物: `templates/monitoring/cloudwatch-alarms-tgw.yaml`

### PMへの確認事項

1. **dev環境のコスト最適化戦略**
   - 質問: dev環境でVPC Peering使用を承認しますか？
   - 選択肢A: VPC Peering（$36/月削減、構成差異あり）
   - 選択肢B: TGW（本番同一構成、コスト増）

2. **IAMロール設計のセキュリティレビュー体制**
   - 質問: security-engineerのアサインは可能ですか？
   - 代替案: 外部セキュリティ監査（コスト増）

3. **本番デプロイ実施日時**
   - 質問: メンテナンス時間帯の調整は可能ですか？
   - 推奨: 深夜1:00〜5:00（4時間）

---

## 6. 参考資料

- [AWS Multi-Account Strategy](https://aws.amazon.com/jp/organizations/getting-started/best-practices/)
- [Transit Gateway Best Practices](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-best-design-practices.html)
- [CloudFormation技術標準](.claude/docs/40_standards/42_infra/iac/cloudformation.md)
- [運用手順書](./DEPLOYMENT_GUIDE.md)

---

**レビュー完了日**: 2025-11-10
**次回レビュー**: dev環境検証完了後
**承認ステータス**: ⚠️ 条件付き承認（上記アクション実施後に最終承認）
