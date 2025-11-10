# CloudWatch アラーム詳細

## 目次
1. [アラーム一覧](#アラーム一覧)
2. [本番環境アラーム](#本番環境アラーム)
3. [ステージング環境アラーム](#ステージング環境アラーム)
4. [アラーム作成手順](#アラーム作成手順)

---

## アラーム一覧

### アラーム命名規則

```
<project>-<environment>-<service>-<metric>-<severity>
```

例: `kaigo-subsys-prod-ecs-cpu-critical`

---

## 本番環境アラーム

### ALB アラーム

#### 1. ターゲットレスポンスタイム (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-alb-response-time-warning` |
| メトリクス | `TargetResponseTime` |
| ネームスペース | `AWS/ApplicationELB` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 1秒 |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | ALBターゲットのレスポンスタイムが1秒を超過 |

#### 2. ターゲットレスポンスタイム (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-alb-response-time-critical` |
| メトリクス | `TargetResponseTime` |
| ネームスペース | `AWS/ApplicationELB` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 1回 |
| 閾値 | > 3秒 |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | ALBターゲットのレスポンスタイムが3秒を超過 |

#### 3. 異常なターゲット数

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-alb-unhealthy-targets` |
| メトリクス | `UnHealthyHostCount` |
| ネームスペース | `AWS/ApplicationELB` |
| 統計 | Maximum |
| 期間 | 60秒 (1分) |
| 評価期間 | 2回連続 |
| 閾値 | >= 1 |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | 異常なターゲットが検出された |

#### 4. 5xxエラー (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-alb-5xx-warning` |
| メトリクス | `HTTPCode_Target_5XX_Count` |
| ネームスペース | `AWS/ApplicationELB` |
| 統計 | Sum |
| 期間 | 300秒 (5分) |
| 評価期間 | 1回 |
| 閾値 | > 10 |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | 5xxエラーが5分間で10回を超過 |

#### 5. 5xxエラー (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-alb-5xx-critical` |
| メトリクス | `HTTPCode_Target_5XX_Count` |
| ネームスペース | `AWS/ApplicationELB` |
| 統計 | Sum |
| 期間 | 300秒 (5分) |
| 評価期間 | 1回 |
| 閾値 | > 50 |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | 5xxエラーが5分間で50回を超過 |

### ECS アラーム

#### 1. CPU使用率 (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-ecs-cpu-warning` |
| メトリクス | `CPUUtilization` |
| ネームスペース | `AWS/ECS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 75% |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | ECSタスクのCPU使用率が75%を超過 |

#### 2. CPU使用率 (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-ecs-cpu-critical` |
| メトリクス | `CPUUtilization` |
| ネームスペース | `AWS/ECS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 90% |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | ECSタスクのCPU使用率が90%を超過 |

#### 3. メモリ使用率 (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-ecs-memory-warning` |
| メトリクス | `MemoryUtilization` |
| ネームスペース | `AWS/ECS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 75% |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | ECSタスクのメモリ使用率が75%を超過 |

#### 4. メモリ使用率 (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-ecs-memory-critical` |
| メトリクス | `MemoryUtilization` |
| ネームスペース | `AWS/ECS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 90% |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | ECSタスクのメモリ使用率が90%を超過 |

#### 5. 実行中タスク数

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-ecs-running-tasks-critical` |
| メトリクス | `RunningTaskCount` |
| ネームスペース | `ECS/ContainerInsights` |
| 統計 | Average |
| 期間 | 60秒 (1分) |
| 評価期間 | 2回連続 |
| 閾値 | < 2 |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | 実行中のECSタスクが2未満 |

### RDS アラーム

#### 1. CPU使用率 (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-rds-cpu-warning` |
| メトリクス | `CPUUtilization` |
| ネームスペース | `AWS/RDS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 75% |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | RDSのCPU使用率が75%を超過 |

#### 2. CPU使用率 (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-rds-cpu-critical` |
| メトリクス | `CPUUtilization` |
| ネームスペース | `AWS/RDS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 90% |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | RDSのCPU使用率が90%を超過 |

#### 3. 空きメモリ (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-rds-memory-warning` |
| メトリクス | `FreeableMemory` |
| ネームスペース | `AWS/RDS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | < 1073741824 (1GB) |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | RDSの空きメモリが1GB未満 |

#### 4. 空きメモリ (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-rds-memory-critical` |
| メトリクス | `FreeableMemory` |
| ネームスペース | `AWS/RDS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | < 536870912 (512MB) |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | RDSの空きメモリが512MB未満 |

#### 5. 空きストレージ (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-rds-storage-warning` |
| メトリクス | `FreeStorageSpace` |
| ネームスペース | `AWS/RDS` |
| 統計 | Average |
| 期間 | 3600秒 (1時間) |
| 評価期間 | 1回 |
| 閾値 | < 10737418240 (10GB) |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | RDSの空きストレージが10GB未満 |

#### 6. 空きストレージ (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-rds-storage-critical` |
| メトリクス | `FreeStorageSpace` |
| ネームスペース | `AWS/RDS` |
| 統計 | Average |
| 期間 | 3600秒 (1時間) |
| 評価期間 | 1回 |
| 閾値 | < 5368709120 (5GB) |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | RDSの空きストレージが5GB未満 |

#### 7. データベース接続数 (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-rds-connections-warning` |
| メトリクス | `DatabaseConnections` |
| ネームスペース | `AWS/RDS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 80 |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | RDSのデータベース接続数が80を超過 |

#### 8. レプリケーション遅延 (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-rds-replica-lag-critical` |
| メトリクス | `ReplicaLag` |
| ネームスペース | `AWS/RDS` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 60秒 |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | RDSのレプリケーション遅延が60秒を超過 |

### ElastiCache アラーム

#### 1. CPU使用率 (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-elasticache-cpu-warning` |
| メトリクス | `CPUUtilization` |
| ネームスペース | `AWS/ElastiCache` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 75% |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | ElastiCacheのCPU使用率が75%を超過 |

#### 2. メモリ使用率 (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-elasticache-memory-warning` |
| メトリクス | `DatabaseMemoryUsagePercentage` |
| ネームスペース | `AWS/ElastiCache` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 80% |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | ElastiCacheのメモリ使用率が80%を超過 |

#### 3. メモリ使用率 (Critical)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-elasticache-memory-critical` |
| メトリクス | `DatabaseMemoryUsagePercentage` |
| ネームスペース | `AWS/ElastiCache` |
| 統計 | Average |
| 期間 | 300秒 (5分) |
| 評価期間 | 2回連続 |
| 閾値 | > 90% |
| アクション | `kaigo-subsys-prod-critical-alerts` |
| 説明 | ElastiCacheのメモリ使用率が90%を超過 |

#### 4. キー削除数 (Warning)

| 項目 | 値 |
|------|-----|
| アラーム名 | `kaigo-subsys-prod-elasticache-evictions-warning` |
| メトリクス | `Evictions` |
| ネームスペース | `AWS/ElastiCache` |
| 統計 | Sum |
| 期間 | 60秒 (1分) |
| 評価期間 | 3回連続 |
| 閾値 | > 100 |
| アクション | `kaigo-subsys-prod-warning-alerts` |
| 説明 | ElastiCacheのキー削除数が1分間で100を超過 |

---

## ステージング環境アラーム

### 主要アラームのみ設定

| アラーム名 | メトリクス | 閾値 | アクション |
|-----------|-----------|------|----------|
| `kaigo-subsys-stg-ecs-cpu-critical` | ECS CPU使用率 | > 90% | `kaigo-subsys-stg-alerts` |
| `kaigo-subsys-stg-ecs-memory-critical` | ECS メモリ使用率 | > 90% | `kaigo-subsys-stg-alerts` |
| `kaigo-subsys-stg-rds-cpu-critical` | RDS CPU使用率 | > 90% | `kaigo-subsys-stg-alerts` |
| `kaigo-subsys-stg-rds-storage-warning` | RDS 空きストレージ | < 5GB | `kaigo-subsys-stg-alerts` |

---

## アラーム作成手順

### CloudFormationテンプレート例

```yaml
Resources:
  ALBResponseTimeWarningAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: kaigo-subsys-prod-alb-response-time-warning
      AlarmDescription: ALBターゲットのレスポンスタイムが1秒を超過
      MetricName: TargetResponseTime
      Namespace: AWS/ApplicationELB
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 1.0
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref WarningAlertsTopic
      Dimensions:
        - Name: LoadBalancer
          Value: !Ref ApplicationLoadBalancer

  WarningAlertsTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: kaigo-subsys-prod-warning-alerts
      Subscription:
        - Endpoint: ops-team@example.com
          Protocol: email
        - Endpoint: https://hooks.slack.com/services/XXX
          Protocol: https
```

### AWS CLI例

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name kaigo-subsys-prod-alb-response-time-warning \
  --alarm-description "ALBターゲットのレスポンスタイムが1秒を超過" \
  --metric-name TargetResponseTime \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 1.0 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:kaigo-subsys-prod-warning-alerts \
  --dimensions Name=LoadBalancer,Value=app/kaigo-subsys-prod-alb/xxxxx
```

---

## 関連ドキュメント

- [監視設計](./monitoring_design.md)
- [監視フロー](./monitoring_flow.md)
- [セキュリティ設計](../07_security/security_design.md)

---

**作成日**: 2025-11-05
**作成者**: Architect
**バージョン**: 1.0
