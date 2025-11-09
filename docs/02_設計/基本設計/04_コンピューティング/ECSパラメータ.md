# ECS パラメータシート

## 概要

このドキュメントでは、ECS Fargateの詳細なパラメータを定義します。

---

## ECS Cluster

### 本番環境

```yaml
ClusterName: kaigo-prod-cluster
CapacityProviders:
  - FARGATE
  - FARGATE_SPOT
DefaultCapacityProviderStrategy:
  - CapacityProvider: FARGATE
    Weight: 4
    Base: 2
  - CapacityProvider: FARGATE_SPOT
    Weight: 1
    Base: 0
ContainerInsights: enabled
Tags:
  - Key: Name
    Value: kaigo-prod-cluster
  - Key: Environment
    Value: production
  - Key: Project
    Value: niigata-kaigo
```

### ステージング環境

```yaml
ClusterName: kaigo-stg-cluster
CapacityProviders:
  - FARGATE
DefaultCapacityProviderStrategy:
  - CapacityProvider: FARGATE
    Weight: 1
    Base: 1
ContainerInsights: enabled
Tags:
  - Key: Name
    Value: kaigo-stg-cluster
  - Key: Environment
    Value: staging
  - Key: Project
    Value: niigata-kaigo
```

---

## ECS Task Definition

### 本番環境

```json
{
  "family": "kaigo-prod-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "2048",
  "memory": "4096",
  "taskRoleArn": "arn:aws:iam::{AccountId}:role/kaigo-prod-task-role",
  "executionRoleArn": "arn:aws:iam::{AccountId}:role/kaigo-prod-execution-role",
  "containerDefinitions": [
    {
      "name": "kaigo-app",
      "image": "{AccountId}.dkr.ecr.ap-northeast-1.amazonaws.com/kaigo-prod:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "8080"
        },
        {
          "name": "LOG_LEVEL",
          "value": "info"
        },
        {
          "name": "AWS_REGION",
          "value": "ap-northeast-1"
        }
      ],
      "secrets": [
        {
          "name": "DB_HOST",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/prod/db-xxxxx:host::"
        },
        {
          "name": "DB_NAME",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/prod/db-xxxxx:dbname::"
        },
        {
          "name": "DB_USER",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/prod/db-xxxxx:username::"
        },
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/prod/db-xxxxx:password::"
        },
        {
          "name": "REDIS_HOST",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/prod/redis-xxxxx:host::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/kaigo-prod",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ],
  "tags": [
    {
      "key": "Name",
      "value": "kaigo-prod-task"
    },
    {
      "key": "Environment",
      "value": "production"
    }
  ]
}
```

### ステージング環境

```json
{
  "family": "kaigo-stg-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "taskRoleArn": "arn:aws:iam::{AccountId}:role/kaigo-stg-task-role",
  "executionRoleArn": "arn:aws:iam::{AccountId}:role/kaigo-stg-execution-role",
  "containerDefinitions": [
    {
      "name": "kaigo-app",
      "image": "{AccountId}.dkr.ecr.ap-northeast-1.amazonaws.com/kaigo-stg:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "staging"
        },
        {
          "name": "PORT",
          "value": "8080"
        },
        {
          "name": "LOG_LEVEL",
          "value": "debug"
        },
        {
          "name": "AWS_REGION",
          "value": "ap-northeast-1"
        }
      ],
      "secrets": [
        {
          "name": "DB_HOST",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/stg/db-xxxxx:host::"
        },
        {
          "name": "DB_NAME",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/stg/db-xxxxx:dbname::"
        },
        {
          "name": "DB_USER",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/stg/db-xxxxx:username::"
        },
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/stg/db-xxxxx:password::"
        },
        {
          "name": "REDIS_HOST",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:{AccountId}:secret:kaigo/stg/redis-xxxxx:host::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/kaigo-stg",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8080/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ],
  "tags": [
    {
      "key": "Name",
      "value": "kaigo-stg-task"
    },
    {
      "key": "Environment",
      "value": "staging"
    }
  ]
}
```

---

## ECS Service

### 本番環境

```json
{
  "serviceName": "kaigo-prod-service",
  "cluster": "kaigo-prod-cluster",
  "taskDefinition": "kaigo-prod-task",
  "desiredCount": 4,
  "launchType": "FARGATE",
  "platformVersion": "LATEST",
  "deploymentConfiguration": {
    "maximumPercent": 200,
    "minimumHealthyPercent": 100,
    "deploymentCircuitBreaker": {
      "enable": true,
      "rollback": true
    }
  },
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": [
        "subnet-xxxxx",
        "subnet-yyyyy"
      ],
      "securityGroups": [
        "sg-xxxxx"
      ],
      "assignPublicIp": "DISABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:ap-northeast-1:{AccountId}:targetgroup/kaigo-prod-tg/xxxxx",
      "containerName": "kaigo-app",
      "containerPort": 8080
    }
  ],
  "healthCheckGracePeriodSeconds": 60,
  "enableECSManagedTags": true,
  "propagateTags": "SERVICE",
  "tags": [
    {
      "key": "Name",
      "value": "kaigo-prod-service"
    },
    {
      "key": "Environment",
      "value": "production"
    }
  ]
}
```

### ステージング環境

```json
{
  "serviceName": "kaigo-stg-service",
  "cluster": "kaigo-stg-cluster",
  "taskDefinition": "kaigo-stg-task",
  "desiredCount": 2,
  "launchType": "FARGATE",
  "platformVersion": "LATEST",
  "deploymentConfiguration": {
    "maximumPercent": 200,
    "minimumHealthyPercent": 50,
    "deploymentCircuitBreaker": {
      "enable": true,
      "rollback": true
    }
  },
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": [
        "subnet-xxxxx",
        "subnet-yyyyy"
      ],
      "securityGroups": [
        "sg-xxxxx"
      ],
      "assignPublicIp": "DISABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "arn:aws:elasticloadbalancing:ap-northeast-1:{AccountId}:targetgroup/kaigo-stg-tg/xxxxx",
      "containerName": "kaigo-app",
      "containerPort": 8080
    }
  ],
  "healthCheckGracePeriodSeconds": 60,
  "enableECSManagedTags": true,
  "propagateTags": "SERVICE",
  "tags": [
    {
      "key": "Name",
      "value": "kaigo-stg-service"
    },
    {
      "key": "Environment",
      "value": "staging"
    }
  ]
}
```

---

## Auto Scaling

### 本番環境

```json
{
  "ServiceNamespace": "ecs",
  "ResourceId": "service/kaigo-prod-cluster/kaigo-prod-service",
  "ScalableDimension": "ecs:service:DesiredCount",
  "MinCapacity": 4,
  "MaxCapacity": 20,
  "TargetTrackingScalingPolicyConfiguration": {
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 300
  }
}
```

### ステージング環境

```json
{
  "ServiceNamespace": "ecs",
  "ResourceId": "service/kaigo-stg-cluster/kaigo-stg-service",
  "ScalableDimension": "ecs:service:DesiredCount",
  "MinCapacity": 2,
  "MaxCapacity": 10,
  "TargetTrackingScalingPolicyConfiguration": {
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 300
  }
}
```

---

## CloudFormation Parameters

```yaml
Parameters:
  # Cluster
  ClusterName:
    Type: String
    Default: kaigo-prod-cluster

  # Task Definition
  TaskDefinitionFamily:
    Type: String
    Default: kaigo-prod-task

  TaskCpu:
    Type: String
    Default: "2048"
    AllowedValues:
      - "256"
      - "512"
      - "1024"
      - "2048"
      - "4096"

  TaskMemory:
    Type: String
    Default: "4096"
    AllowedValues:
      - "512"
      - "1024"
      - "2048"
      - "3072"
      - "4096"
      - "5120"
      - "6144"
      - "7168"
      - "8192"

  ContainerImage:
    Type: String
    Default: "{AccountId}.dkr.ecr.ap-northeast-1.amazonaws.com/kaigo-prod:latest"

  # Service
  ServiceName:
    Type: String
    Default: kaigo-prod-service

  DesiredCount:
    Type: Number
    Default: 4
    MinValue: 1
    MaxValue: 100

  # Auto Scaling
  MinCapacity:
    Type: Number
    Default: 4
    MinValue: 1
    MaxValue: 100

  MaxCapacity:
    Type: Number
    Default: 20
    MinValue: 1
    MaxValue: 100

  TargetCpuUtilization:
    Type: Number
    Default: 70
    MinValue: 1
    MaxValue: 100
```

---

**作成者**: architect
**レビュー状態**: Draft
**関連ドキュメント**: [compute_design.md](compute_design.md)
