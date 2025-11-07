# DR (災害復旧) 手順書

## 目次
1. [DR発動判断](#dr発動判断)
2. [DR手順](#dr手順)
3. [切り戻し手順](#切り戻し手順)
4. [DR訓練](#dr訓練)

---

## DR発動判断

### DR発動基準

| シナリオ | 発動基準 | 判断者 |
|---------|---------|--------|
| リージョン全停止 | AWS公式発表で4時間以上の復旧見込み | システム管理者 + 管理職 |
| 複数AZ障害 | 2つ以上のAZで障害、2時間以上の復旧見込み | システム管理者 |
| データセンター火災 | AWS公式発表で災害レベルの障害 | システム管理者 + 管理職 |
| ランサムウェア攻撃 | データ暗号化、復旧に8時間以上かかる | セキュリティチーム + 管理職 |

### DR発動チェックリスト

- [ ] AWS公式発表を確認
- [ ] 影響範囲を確認（全サービス停止か、一部か）
- [ ] 復旧見込み時間を確認
- [ ] 代替手段（他のAZへの切り替え等）を検討
- [ ] DR発動による影響（データ損失、コスト）を確認
- [ ] 経営層の承認を取得

---

## DR手順

### フェーズ1: DR発動準備 (30分)

#### ステップ1: 状況確認と意思決定

**担当**: システム管理者、管理職

```bash
# AWS Health Dashboard確認
# https://health.aws.amazon.com/health/home

# 影響を受けているサービス確認
aws health describe-events \
  --filter eventTypeCategories=issue,accountSpecific=false \
  --query "events[?eventTypeCode=='AWS_EC2_OPERATIONAL_ISSUE' && region=='us-east-1']" \
  --region us-east-1
```

**判断ポイント**:
- AWS公式発表内容
- 復旧見込み時間
- ユーザー影響
- DR発動によるデータ損失（RPO 1時間）の許容可否

#### ステップ2: 関係者への通知

**担当**: システム管理者

- [ ] 開発チームへ通知
- [ ] 運用チームへ通知
- [ ] 経営層へ通知
- [ ] ユーザーへメンテナンス通知（Webサイト、Email）

---

### フェーズ2: DR環境構築 (2時間)

#### ステップ3: VPCとネットワークの確認

**担当**: ネットワーク担当者

**前提**: VPC、サブネット、セキュリティグループは事前構築済み

```bash
# DR環境のVPC確認
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=kaigo-subsys-dr-vpc" \
  --region us-west-2

# サブネット確認
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-dr-xxxxx" \
  --region us-west-2
```

**確認項目**:
- [ ] VPC存在確認
- [ ] サブネット存在確認
- [ ] セキュリティグループ存在確認
- [ ] ルートテーブル確認

#### ステップ4: RDSの復元

**担当**: データベース担当者

**所要時間**: 30-60分

```bash
# 1. 最新のスナップショット確認 (us-west-2)
aws rds describe-db-snapshots \
  --db-instance-identifier kaigo-subsys-prod \
  --region us-west-2 \
  --query "DBSnapshots[?Status=='available'] | sort_by(@, &SnapshotCreateTime)[-1]" \
  --output json

# 2. スナップショットから復元
SNAPSHOT_ID="rds:kaigo-subsys-prod-2025-01-15-03-00"

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier kaigo-subsys-dr \
  --db-snapshot-identifier ${SNAPSHOT_ID} \
  --db-instance-class db.r6g.large \
  --db-subnet-group-name kaigo-subsys-dr-db-subnet-group \
  --vpc-security-group-ids sg-dr-rds-xxxxx \
  --publicly-accessible false \
  --multi-az true \
  --region us-west-2

# 3. 復元完了まで待機
aws rds wait db-instance-available \
  --db-instance-identifier kaigo-subsys-dr \
  --region us-west-2

# 4. エンドポイント取得
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier kaigo-subsys-dr \
  --region us-west-2 \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

echo "RDS Endpoint: ${RDS_ENDPOINT}"
```

**確認項目**:
- [ ] スナップショット復元完了
- [ ] マルチAZ構成確認
- [ ] エンドポイント取得
- [ ] 接続テスト（psqlコマンド）

#### ステップ5: ElastiCacheの起動

**担当**: インフラ担当者

**所要時間**: 15分

```bash
# ElastiCacheクラスター作成
aws elasticache create-replication-group \
  --replication-group-id kaigo-subsys-dr \
  --replication-group-description "DR ElastiCache for kaigo subsystem" \
  --engine redis \
  --cache-node-type cache.r6g.large \
  --num-cache-clusters 2 \
  --automatic-failover-enabled \
  --cache-subnet-group-name kaigo-subsys-dr-cache-subnet-group \
  --security-group-ids sg-dr-elasticache-xxxxx \
  --engine-version 7.0 \
  --region us-west-2

# 起動完了まで待機 (約15分)
aws elasticache wait replication-group-available \
  --replication-group-id kaigo-subsys-dr \
  --region us-west-2

# エンドポイント取得
REDIS_ENDPOINT=$(aws elasticache describe-replication-groups \
  --replication-group-id kaigo-subsys-dr \
  --region us-west-2 \
  --query "ReplicationGroups[0].ConfigurationEndpoint.Address" \
  --output text)

echo "Redis Endpoint: ${REDIS_ENDPOINT}"
```

**注意**: ElastiCacheはバックアップからの復元ではなく、新規作成。キャッシュは空の状態から開始。

#### ステップ6: EFSの復元

**担当**: ストレージ担当者

**所要時間**: 30分

```bash
# 1. 最新のEFSバックアップ確認
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name kaigo-subsys-dr-backup-vault \
  --region us-west-2 \
  --query "RecoveryPoints[?ResourceType=='EFS'] | sort_by(@, &CreationDate)[-1]"

# 2. EFS復元
RECOVERY_POINT_ARN="arn:aws:backup:us-west-2:123456789012:recovery-point:xxxxx"

aws backup start-restore-job \
  --recovery-point-arn ${RECOVERY_POINT_ARN} \
  --metadata "file-system-id=fs-dr-xxxxx,PerformanceMode=generalPurpose,Encrypted=true" \
  --iam-role-arn arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole \
  --region us-west-2

# 3. 復元完了まで待機
# (AWS Backupコンソールで確認)
```

#### ステップ7: ECS サービスの起動

**担当**: アプリケーション担当者

**所要時間**: 15分

```bash
# 1. 環境変数を更新 (RDS、ElastiCache、EFSエンドポイント)
# Secrets Managerまたはパラメータストアを更新

aws secretsmanager update-secret \
  --secret-id kaigo-subsys/dr/db-endpoint \
  --secret-string "{\"endpoint\":\"${RDS_ENDPOINT}\"}" \
  --region us-west-2

aws secretsmanager update-secret \
  --secret-id kaigo-subsys/dr/redis-endpoint \
  --secret-string "{\"endpoint\":\"${REDIS_ENDPOINT}\"}" \
  --region us-west-2

# 2. ECS タスク定義更新
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definition-dr.json \
  --region us-west-2

# 3. ECS サービス更新 (desired count を 2に)
aws ecs update-service \
  --cluster kaigo-subsys-dr \
  --service kaigo-subsys-dr-service \
  --desired-count 2 \
  --task-definition kaigo-subsys-dr:latest \
  --region us-west-2

# 4. タスク起動確認
aws ecs wait services-stable \
  --cluster kaigo-subsys-dr \
  --services kaigo-subsys-dr-service \
  --region us-west-2
```

**確認項目**:
- [ ] タスク定義更新
- [ ] 2タスク起動確認
- [ ] ヘルスチェック成功確認

#### ステップ8: ALBの起動

**担当**: インフラ担当者

**所要時間**: 5分

```bash
# ALBターゲットグループのヘルスチェック確認
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/kaigo-subsys-dr/xxxxx \
  --region us-west-2

# ヘルスチェックが成功するまで待機（約2分）
```

**確認項目**:
- [ ] ターゲットグループに2つのターゲットが登録されている
- [ ] ヘルスチェックが `healthy` 状態
- [ ] ALBのDNS名を取得

---

### フェーズ3: DNS切り替え (30分)

#### ステップ9: Route 53 DNS切り替え

**担当**: ネットワーク担当者

**所要時間**: 5分（浸透に最大1分）

```bash
# 1. 現在のDNSレコード確認
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --query "ResourceRecordSets[?Name=='api.kaigo-subsys.example.com.']"

# 2. DNSレコード更新 (ALIASレコード)
cat > change-batch.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.kaigo-subsys.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z1BKCTXD74EZPE",
          "DNSName": "kaigo-subsys-dr-alb-xxxxx.us-west-2.elb.amazonaws.com",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://change-batch.json

# 3. DNS浸透確認 (TTL 60秒のため、最大1分)
dig api.kaigo-subsys.example.com
```

**確認項目**:
- [ ] DNS変更完了
- [ ] dig コマンドでDR環境のIPアドレスが返ってくる
- [ ] TTL 60秒を確認

---

### フェーズ4: 動作確認 (1時間)

#### ステップ10: システム動作確認

**担当**: 開発チーム、QAチーム

**所要時間**: 1時間

**確認項目**:

1. **ヘルスチェック**
   ```bash
   curl https://api.kaigo-subsys.example.com/health
   # 期待結果: {"status":"ok"}
   ```

2. **認証機能**
   - ログイン成功
   - セッション維持

3. **主要機能**
   - データ検索
   - データ登録
   - データ更新
   - データ削除

4. **パフォーマンス**
   - レスポンスタイム < 3秒
   - エラー率 < 1%

5. **データ整合性**
   - 最新データの確認（RPO 1時間以内）
   - データ欠損の有無

#### ステップ11: 監視設定

**担当**: 運用担当者

```bash
# CloudWatch アラームの切り替え（DR環境用）
aws cloudwatch put-metric-alarm \
  --alarm-name kaigo-subsys-dr-ecs-cpu-critical \
  --alarm-description "DR環境のECS CPU使用率が90%を超過" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 90.0 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value=kaigo-subsys-dr Name=ServiceName,Value=kaigo-subsys-dr-service \
  --alarm-actions arn:aws:sns:us-west-2:123456789012:kaigo-subsys-dr-critical-alerts \
  --region us-west-2
```

**確認項目**:
- [ ] CloudWatch アラーム設定
- [ ] ダッシュボード確認
- [ ] ログ出力確認

---

### フェーズ5: ユーザー通知と運用開始

#### ステップ12: ユーザー通知

**担当**: カスタマーサポート、広報

- [ ] Webサイトにメンテナンス終了通知
- [ ] Emailでサービス再開通知
- [ ] 障害報告書の準備

---

## 切り戻し手順

### 本番環境 (us-east-1) 復旧後の切り戻し

#### フェーズ1: 本番環境の復旧確認 (30分)

**担当**: システム管理者

1. **AWS公式発表確認**
   - us-east-1 リージョンの復旧完了宣言

2. **本番環境の動作確認**
   - VPC、サブネット確認
   - RDSインスタンス起動確認
   - ECS クラスター確認

#### フェーズ2: データ同期 (1-2時間)

**担当**: データベース担当者

**課題**: DR期間中に更新されたデータを本番環境に反映

**手順**:

1. **DR環境のRDSスナップショット作成**
   ```bash
   aws rds create-db-snapshot \
     --db-instance-identifier kaigo-subsys-dr \
     --db-snapshot-identifier kaigo-subsys-dr-before-cutback-$(date +%Y%m%d-%H%M%S) \
     --region us-west-2
   ```

2. **スナップショットをus-east-1にコピー**
   ```bash
   aws rds copy-db-snapshot \
     --source-db-snapshot-identifier arn:aws:rds:us-west-2:123456789012:snapshot:kaigo-subsys-dr-before-cutback-xxxxx \
     --target-db-snapshot-identifier kaigo-subsys-prod-cutback \
     --region us-east-1 \
     --kms-key-id arn:aws:kms:us-east-1:123456789012:key/prod-key-id
   ```

3. **本番RDSを復元**
   ```bash
   # 既存の本番RDSを削除（最終スナップショット取得）
   aws rds delete-db-instance \
     --db-instance-identifier kaigo-subsys-prod \
     --final-db-snapshot-identifier kaigo-subsys-prod-final-before-cutback \
     --region us-east-1

   # DR環境のスナップショットから復元
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier kaigo-subsys-prod \
     --db-snapshot-identifier kaigo-subsys-prod-cutback \
     --db-instance-class db.r6g.large \
     --db-subnet-group-name kaigo-subsys-prod-db-subnet-group \
     --vpc-security-group-ids sg-prod-rds-xxxxx \
     --multi-az true \
     --region us-east-1
   ```

#### フェーズ3: DNS切り戻し (30分)

**担当**: ネットワーク担当者

```bash
# Route 53 DNSレコード更新
cat > change-batch-cutback.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.kaigo-subsys.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z35SXDOTRQ7X7K",
          "DNSName": "kaigo-subsys-prod-alb-xxxxx.us-east-1.elb.amazonaws.com",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://change-batch-cutback.json
```

#### フェーズ4: DR環境の停止

**担当**: インフラ担当者

```bash
# ECS サービス停止
aws ecs update-service \
  --cluster kaigo-subsys-dr \
  --service kaigo-subsys-dr-service \
  --desired-count 0 \
  --region us-west-2

# RDS停止
aws rds stop-db-instance \
  --db-instance-identifier kaigo-subsys-dr \
  --region us-west-2

# ElastiCache削除（コスト削減）
aws elasticache delete-replication-group \
  --replication-group-id kaigo-subsys-dr \
  --region us-west-2
```

---

## DR訓練

### 訓練計画

| 訓練種別 | 頻度 | 参加者 |
|---------|------|--------|
| 机上訓練 | 四半期ごと | システム管理者、開発チーム |
| 部分訓練 | 半年ごと | システム管理者、運用チーム、開発チーム |
| フルスケール訓練 | 年1回 | 全チーム + 経営層 |

### フルスケール訓練の流れ

**日時**: 2025-12-01 (土) 09:00-17:00

**参加者**: 全チーム

**シナリオ**: us-east-1 リージョン全停止

**タイムライン**:

| 時刻 | アクション | 担当 |
|------|----------|------|
| 09:00 | 訓練開始宣言 | 管理職 |
| 09:10 | DR発動判断 | システム管理者 + 管理職 |
| 09:30 | DR環境構築開始 | インフラチーム |
| 11:30 | DR環境構築完了 | インフラチーム |
| 11:45 | DNS切り替え | ネットワークチーム |
| 13:00 | 動作確認完了 | 開発チーム、QAチーム |
| 13:30 | 切り戻し準備 | システム管理者 |
| 15:00 | 切り戻し完了 | インフラチーム |
| 15:30 | 動作確認完了 | 開発チーム |
| 16:00 | 振り返りミーティング | 全チーム |
| 17:00 | 訓練終了 | 管理職 |

### 訓練後のレポート

**記載項目**:
- 実施日時
- 参加者
- タイムライン（実績）
- 問題点
- 改善提案
- 次回訓練の予定

---

## 関連ドキュメント

- [バックアップ・DR設計](./backup_dr_design.md)
- [バックアップフロー](./backup_flow.md)
- [監視設計](../08_monitoring/monitoring_design.md)

---

**作成日**: 2025-11-05
**作成者**: Architect
**バージョン**: 1.0
