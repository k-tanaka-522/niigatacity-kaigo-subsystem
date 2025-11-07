# ALB パラメータシート

## 概要

Application Load Balancerの詳細なパラメータを定義します。

---

## Application Load Balancer

### 本番環境

```json
{
  "Name": "kaigo-prod-alb",
  "Subnets": [
    "subnet-xxxxx",
    "subnet-yyyyy"
  ],
  "SecurityGroups": [
    "sg-xxxxx"
  ],
  "Scheme": "internet-facing",
  "Type": "application",
  "IpAddressType": "ipv4",
  "Tags": [
    {
      "Key": "Name",
      "Value": "kaigo-prod-alb"
    },
    {
      "Key": "Environment",
      "Value": "production"
    }
  ]
}
```

### アクセスログ設定

```json
{
  "Enabled": true,
  "S3BucketName": "kaigo-prod-alb-logs",
  "S3Prefix": "alb-access-logs"
}
```

---

## Target Group

### 本番環境

```json
{
  "Name": "kaigo-prod-tg",
  "Protocol": "HTTP",
  "Port": 8080,
  "VpcId": "vpc-xxxxx",
  "TargetType": "ip",
  "HealthCheckProtocol": "HTTP",
  "HealthCheckPath": "/health",
  "HealthCheckIntervalSeconds": 30,
  "HealthCheckTimeoutSeconds": 5,
  "HealthyThresholdCount": 2,
  "UnhealthyThresholdCount": 2,
  "Matcher": {
    "HttpCode": "200"
  },
  "DeregistrationDelay": 30,
  "Stickiness": {
    "Enabled": true,
    "Type": "lb_cookie",
    "Duration": 3600
  },
  "Tags": [
    {
      "Key": "Name",
      "Value": "kaigo-prod-tg"
    }
  ]
}
```

---

## Listener (HTTPS)

```json
{
  "LoadBalancerArn": "arn:aws:elasticloadbalancing:ap-northeast-1:{AccountId}:loadbalancer/app/kaigo-prod-alb/xxxxx",
  "Protocol": "HTTPS",
  "Port": 443,
  "Certificates": [
    {
      "CertificateArn": "arn:aws:acm:ap-northeast-1:{AccountId}:certificate/xxxxx"
    }
  ],
  "SslPolicy": "ELBSecurityPolicy-TLS13-1-2-2021-06",
  "DefaultActions": [
    {
      "Type": "forward",
      "TargetGroupArn": "arn:aws:elasticloadbalancing:ap-northeast-1:{AccountId}:targetgroup/kaigo-prod-tg/xxxxx"
    }
  ]
}
```

---

## Listener (HTTP - Redirect)

```json
{
  "LoadBalancerArn": "arn:aws:elasticloadbalancing:ap-northeast-1:{AccountId}:loadbalancer/app/kaigo-prod-alb/xxxxx",
  "Protocol": "HTTP",
  "Port": 80,
  "DefaultActions": [
    {
      "Type": "redirect",
      "RedirectConfig": {
        "Protocol": "HTTPS",
        "Port": "443",
        "StatusCode": "HTTP_301"
      }
    }
  ]
}
```

---

## CloudFormation Parameters

```yaml
Parameters:
  ALBName:
    Type: String
    Default: kaigo-prod-alb

  ALBScheme:
    Type: String
    Default: internet-facing
    AllowedValues:
      - internet-facing
      - internal

  TargetGroupName:
    Type: String
    Default: kaigo-prod-tg

  HealthCheckPath:
    Type: String
    Default: /health

  HealthCheckInterval:
    Type: Number
    Default: 30

  HealthCheckTimeout:
    Type: Number
    Default: 5

  HealthyThreshold:
    Type: Number
    Default: 2

  UnhealthyThreshold:
    Type: Number
    Default: 2

  ACMCertificateArn:
    Type: String
    Description: ARN of ACM certificate for HTTPS

  AccessLogsBucket:
    Type: String
    Default: kaigo-prod-alb-logs
```

---

**作成者**: architect
**レビュー状態**: Draft
