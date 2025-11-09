# RDS パラメータシート

## 概要

RDS MySQLの詳細なパラメータをCloudFormation形式で定義します。

---

## CloudFormation Parameters

```yaml
Parameters:
  DBInstanceIdentifier:
    Type: String
    Default: kaigo-prod-mysql
    Description: DB instance identifier

  DBInstanceClass:
    Type: String
    Default: db.r6g.large
    AllowedValues:
      - db.t4g.medium
      - db.t4g.large
      - db.r6g.large
      - db.r6g.xlarge
      - db.r6g.2xlarge

  Engine:
    Type: String
    Default: mysql
    AllowedValues:
      - mysql

  EngineVersion:
    Type: String
    Default: "8.0.35"

  MasterUsername:
    Type: String
    Default: admin
    NoEcho: true

  MasterUserPassword:
    Type: String
    NoEcho: true
    Description: Master user password (stored in Secrets Manager)

  DBName:
    Type: String
    Default: kaigo_db

  AllocatedStorage:
    Type: Number
    Default: 100
    MinValue: 20
    MaxValue: 16384

  MaxAllocatedStorage:
    Type: Number
    Default: 500
    MinValue: 21
    MaxValue: 16384

  StorageType:
    Type: String
    Default: gp3
    AllowedValues:
      - gp2
      - gp3
      - io1

  Iops:
    Type: Number
    Default: 3000
    MinValue: 1000
    MaxValue: 64000

  StorageThroughput:
    Type: Number
    Default: 125
    MinValue: 125
    MaxValue: 1000

  MultiAZ:
    Type: String
    Default: "true"
    AllowedValues:
      - "true"
      - "false"

  BackupRetentionPeriod:
    Type: Number
    Default: 7
    MinValue: 0
    MaxValue: 35

  PreferredBackupWindow:
    Type: String
    Default: "17:00-18:00"
    Description: "Backup window in UTC (JST: 02:00-03:00)"

  PreferredMaintenanceWindow:
    Type: String
    Default: "sun:10:00-sun:11:00"
    Description: "Maintenance window in UTC (JST: Sun 19:00-20:00)"

  EnablePerformanceInsights:
    Type: String
    Default: "true"
    AllowedValues:
      - "true"
      - "false"

  PerformanceInsightsRetentionPeriod:
    Type: Number
    Default: 7
    AllowedValues:
      - 7
      - 731

  EnableEnhancedMonitoring:
    Type: String
    Default: "true"
    AllowedValues:
      - "true"
      - "false"

  MonitoringInterval:
    Type: Number
    Default: 60
    AllowedValues:
      - 0
      - 1
      - 5
      - 10
      - 15
      - 30
      - 60

  EnableDeletionProtection:
    Type: String
    Default: "true"
    AllowedValues:
      - "true"
      - "false"

  EnableEncryption:
    Type: String
    Default: "true"
    AllowedValues:
      - "true"
      - "false"

  KmsKeyId:
    Type: String
    Description: "ARN of KMS key for encryption"

  PubliclyAccessible:
    Type: String
    Default: "false"
    AllowedValues:
      - "true"
      - "false"
```

---

## DB Parameter Group Parameters

```yaml
Parameters:
  ParameterGroupName:
    Type: String
    Default: kaigo-prod-mysql-params

  ParameterGroupFamily:
    Type: String
    Default: mysql8.0

  # MySQL Parameters
  CharacterSetServer:
    Type: String
    Default: utf8mb4

  CollationServer:
    Type: String
    Default: utf8mb4_unicode_ci

  MaxConnections:
    Type: Number
    Default: 150
    MinValue: 1
    MaxValue: 16000

  InnodbBufferPoolSize:
    Type: String
    Default: "{DBInstanceClassMemory*3/4}"
    Description: "75% of instance memory"

  LogBinTrustFunctionCreators:
    Type: Number
    Default: 1
    AllowedValues:
      - 0
      - 1

  TimeZone:
    Type: String
    Default: "Asia/Tokyo"

  SlowQueryLog:
    Type: Number
    Default: 1
    AllowedValues:
      - 0
      - 1

  LongQueryTime:
    Type: Number
    Default: 2
    MinValue: 0
    MaxValue: 31536000

  GeneralLog:
    Type: Number
    Default: 0
    AllowedValues:
      - 0
      - 1

  BinlogFormat:
    Type: String
    Default: ROW
    AllowedValues:
      - ROW
      - STATEMENT
      - MIXED

  InnodbFlushLogAtTrxCommit:
    Type: Number
    Default: 1
    AllowedValues:
      - 0
      - 1
      - 2

  InnodbLogBufferSize:
    Type: Number
    Default: 16777216
    MinValue: 262144
    MaxValue: 4294967295

  MaxAllowedPacket:
    Type: Number
    Default: 67108864
    MinValue: 1024
    MaxValue: 1073741824
```

---

## CloudFormation Resource Example

```yaml
Resources:
  DBSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupName: !Ref DBSubnetGroupName
      DBSubnetGroupDescription: Subnet group for RDS MySQL
      SubnetIds:
        - !Ref PrivateSubnetA
        - !Ref PrivateSubnetC
      Tags:
        - Key: Name
          Value: !Ref DBSubnetGroupName
        - Key: Environment
          Value: !Ref Environment

  DBParameterGroup:
    Type: AWS::RDS::DBParameterGroup
    Properties:
      DBParameterGroupName: !Ref ParameterGroupName
      Family: !Ref ParameterGroupFamily
      Description: Custom parameter group for MySQL 8.0
      Parameters:
        character_set_server: !Ref CharacterSetServer
        collation_server: !Ref CollationServer
        max_connections: !Ref MaxConnections
        innodb_buffer_pool_size: !Ref InnodbBufferPoolSize
        log_bin_trust_function_creators: !Ref LogBinTrustFunctionCreators
        time_zone: !Ref TimeZone
        slow_query_log: !Ref SlowQueryLog
        long_query_time: !Ref LongQueryTime
        general_log: !Ref GeneralLog
        binlog_format: !Ref BinlogFormat
        innodb_flush_log_at_trx_commit: !Ref InnodbFlushLogAtTrxCommit
        innodb_log_buffer_size: !Ref InnodbLogBufferSize
        max_allowed_packet: !Ref MaxAllowedPacket
      Tags:
        - Key: Name
          Value: !Ref ParameterGroupName
        - Key: Environment
          Value: !Ref Environment

  DBInstance:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Snapshot
    UpdateReplacePolicy: Snapshot
    Properties:
      DBInstanceIdentifier: !Ref DBInstanceIdentifier
      DBInstanceClass: !Ref DBInstanceClass
      Engine: !Ref Engine
      EngineVersion: !Ref EngineVersion
      MasterUsername: !Ref MasterUsername
      MasterUserPassword: !Ref MasterUserPassword
      DBName: !Ref DBName
      AllocatedStorage: !Ref AllocatedStorage
      MaxAllocatedStorage: !Ref MaxAllocatedStorage
      StorageType: !Ref StorageType
      Iops: !If [UseGp3Storage, !Ref Iops, !Ref AWS::NoValue]
      StorageThroughput: !If [UseGp3Storage, !Ref StorageThroughput, !Ref AWS::NoValue]
      StorageEncrypted: !Ref EnableEncryption
      KmsKeyId: !If [UseEncryption, !Ref KmsKeyId, !Ref AWS::NoValue]
      MultiAZ: !Ref MultiAZ
      DBSubnetGroupName: !Ref DBSubnetGroup
      VPCSecurityGroups:
        - !Ref DBSecurityGroup
      PubliclyAccessible: !Ref PubliclyAccessible
      BackupRetentionPeriod: !Ref BackupRetentionPeriod
      PreferredBackupWindow: !Ref PreferredBackupWindow
      PreferredMaintenanceWindow: !Ref PreferredMaintenanceWindow
      CopyTagsToSnapshot: true
      DeletionProtection: !Ref EnableDeletionProtection
      EnablePerformanceInsights: !Ref EnablePerformanceInsights
      PerformanceInsightsRetentionPeriod: !If [EnablePerfInsights, !Ref PerformanceInsightsRetentionPeriod, !Ref AWS::NoValue]
      MonitoringInterval: !If [EnableMonitoring, !Ref MonitoringInterval, 0]
      MonitoringRoleArn: !If [EnableMonitoring, !GetAtt MonitoringRole.Arn, !Ref AWS::NoValue]
      EnableCloudwatchLogsExports:
        - error
        - general
        - slowquery
      DBParameterGroupName: !Ref DBParameterGroup
      Tags:
        - Key: Name
          Value: !Ref DBInstanceIdentifier
        - Key: Environment
          Value: !Ref Environment
        - Key: Project
          Value: niigata-kaigo

Conditions:
  UseGp3Storage: !Equals [!Ref StorageType, gp3]
  UseEncryption: !Equals [!Ref EnableEncryption, "true"]
  EnablePerfInsights: !Equals [!Ref EnablePerformanceInsights, "true"]
  EnableMonitoring: !Equals [!Ref EnableEnhancedMonitoring, "true"]

Outputs:
  DBInstanceEndpoint:
    Description: DB instance endpoint
    Value: !GetAtt DBInstance.Endpoint.Address
    Export:
      Name: !Sub "${AWS::StackName}-DBEndpoint"

  DBInstancePort:
    Description: DB instance port
    Value: !GetAtt DBInstance.Endpoint.Port
    Export:
      Name: !Sub "${AWS::StackName}-DBPort"

  DBInstanceArn:
    Description: DB instance ARN
    Value: !GetAtt DBInstance.DBInstanceArn
    Export:
      Name: !Sub "${AWS::StackName}-DBArn"
```

---

**作成者**: architect
**レビュー状態**: Draft
**関連ドキュメント**: [database_design.md](database_design.md)
