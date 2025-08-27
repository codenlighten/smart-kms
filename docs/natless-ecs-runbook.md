# NAT-less ECS Fargate Operations Runbook

## Quick Health Check Commands

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster universal-foundation-PROD-cluster \
  --services universal-foundation-PROD-sign-service \
  --query 'services[0].[serviceName,runningCount,pendingCount,desiredCount]'

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names uf-PROD-sign-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text) \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]'

# Check latest task status
LATEST_TASK=$(aws ecs list-tasks \
  --cluster universal-foundation-PROD-cluster \
  --service universal-foundation-PROD-sign-service \
  --query 'taskArns[0]' \
  --output text)

aws ecs describe-tasks \
  --cluster universal-foundation-PROD-cluster \
  --tasks $LATEST_TASK \
  --query 'tasks[0].[lastStatus,containers[0].[name,lastStatus,reason]]'
```

## Troubleshooting NAT-less Container Pulls

### 1. Container Pull Errors (CannotPullContainerError)

**Symptoms:**
- Tasks stuck in PENDING status
- Error: `dial tcp [PUBLIC_IP]:443: i/o timeout`
- Tasks failing to start

**Diagnosis:**
```bash
# Check VPC endpoint status
aws ec2 describe-vpc-endpoints \
  --filters Name=vpc-id,Values=vpc-044aa7850ab23825b \
  --query 'VpcEndpoints[].[VpcEndpointId,ServiceName,State,PrivateDnsEnabled]'

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids sg-05f938a99244ecb4c \
  --query 'SecurityGroups[0].IpPermissionsEgress[]'

# Check VPC DNS settings
aws ec2 describe-vpcs \
  --vpc-ids vpc-044aa7850ab23825b \
  --query 'Vpcs[0].[EnableDnsHostnames,EnableDnsSupport]'
```

**Common Fixes:**

1. **Security Group Egress Missing S3 Prefix List:**
```bash
# Add S3 egress rule
aws ec2 authorize-security-group-egress \
  --group-id sg-05f938a99244ecb4c \
  --ip-permissions 'IpProtocol=tcp,FromPort=443,ToPort=443,PrefixListIds=[{PrefixListId=pl-63a5400a}]'
```

2. **VPC Endpoints Missing Private DNS:**
```bash
# Check if Private DNS is enabled
aws ec2 describe-vpc-endpoints \
  --filters Name=service-name,Values=com.amazonaws.us-east-1.ecr.api \
  --query 'VpcEndpoints[0].PrivateDnsEnabled'

# If false, recreate the endpoint with Private DNS enabled
```

3. **VPC DNS Settings Disabled:**
```bash
# Enable DNS hostnames and support
aws ec2 modify-vpc-attribute \
  --vpc-id vpc-044aa7850ab23825b \
  --enable-dns-hostnames

aws ec2 modify-vpc-attribute \
  --vpc-id vpc-044aa7850ab23825b \
  --enable-dns-support
```

### 2. Service Discovery / DNS Issues

**Test DNS Resolution from within VPC:**
```bash
# Run debug container
aws ecs run-task \
  --cluster universal-foundation-PROD-cluster \
  --task-definition debug-dns:1 \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-0f9814a634dde5ee7],securityGroups=[sg-05f938a99244ecb4c],assignPublicIp=DISABLED}" \
  --launch-type FARGATE

# Check logs for DNS resolution results
aws logs get-log-events \
  --log-group-name /ecs/debug-dns \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name /ecs/debug-dns \
    --query 'logStreams[0].logStreamName' \
    --output text)
```

### 3. S3 Layer Download Issues

**Check S3 Gateway Endpoint Association:**
```bash
# Verify S3 endpoint is associated with private route tables
aws ec2 describe-vpc-endpoints \
  --filters Name=service-name,Values=com.amazonaws.us-east-1.s3 \
  --query 'VpcEndpoints[0].RouteTableIds'

# Verify route table associations
aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=vpc-044aa7850ab23825b \
  --query 'RouteTables[].[RouteTableId,Associations[?SubnetId].SubnetId]'
```

## Monitoring & Alerts

### CloudWatch Alarms to Monitor

1. **UnHealthyHostCount > 0** - ALB targets failing health checks
2. **RunningTaskCount < DesiredCount** - Service not maintaining desired tasks
3. **HTTPCode_Target_5XX_Count > threshold** - Application errors
4. **ContainerPullErrors > 0** - Infrastructure issues

### Log Analysis

**Check for common error patterns:**
```bash
# Container pull errors
aws logs filter-log-events \
  --log-group-name /ecs/universal-foundation-PROD-sign-service \
  --filter-pattern "CannotPullContainerError"

# Application errors
aws logs filter-log-events \
  --log-group-name /ecs/universal-foundation-PROD-sign-service \
  --filter-pattern "ERROR"

# Task failures
aws logs filter-log-events \
  --log-group-name /ecs/universal-foundation-PROD-sign-service \
  --filter-pattern "Task stopped"
```

## Scaling Operations

### Manual Scaling
```bash
# Scale up service
aws ecs update-service \
  --cluster universal-foundation-PROD-cluster \
  --service universal-foundation-PROD-sign-service \
  --desired-count 4

# Scale down service
aws ecs update-service \
  --cluster universal-foundation-PROD-cluster \
  --service universal-foundation-PROD-sign-service \
  --desired-count 1
```

### Force New Deployment
```bash
# Force new deployment (useful after infrastructure changes)
aws ecs update-service \
  --cluster universal-foundation-PROD-cluster \
  --service universal-foundation-PROD-sign-service \
  --force-new-deployment
```

## Security Hardening Checklist

- [ ] VPC endpoints have restrictive security groups (443 from tasks only)
- [ ] ECS tasks have least-privilege IAM policies
- [ ] KMS key policy scoped to specific service roles
- [ ] ALB has WAF enabled (if applicable)
- [ ] CloudTrail logging enabled for KMS and DynamoDB data events
- [ ] Secrets Manager used for sensitive environment variables
- [ ] Container images scanned for vulnerabilities

## Cost Optimization

**NAT-less savings:** ~$45/month per AZ (No NAT Gateway charges)

**Monitor costs:**
```bash
# Check VPC endpoint costs (charged per hour + data processing)
aws ce get-cost-and-usage \
  --time-period Start=2025-08-01,End=2025-08-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter file://vpc-endpoint-filter.json
```

## Emergency Procedures

### 1. Complete Service Failure
```bash
# Check cluster capacity
aws ecs describe-clusters --clusters universal-foundation-PROD-cluster

# Check service events
aws ecs describe-services \
  --cluster universal-foundation-PROD-cluster \
  --services universal-foundation-PROD-sign-service \
  --query 'services[0].events[0:5]'

# Temporary rollback to working task definition
aws ecs update-service \
  --cluster universal-foundation-PROD-cluster \
  --service universal-foundation-PROD-sign-service \
  --task-definition universal-foundation-PROD-sign-service:LAST_KNOWN_GOOD
```

### 2. VPC Endpoint Failure
```bash
# Temporary: Add NAT Gateway for emergency connectivity
aws ec2 create-nat-gateway \
  --subnet-id subnet-0f9814a634dde5ee7 \
  --allocation-id $(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# Add route to private route table (TEMPORARY ONLY)
aws ec2 create-route \
  --route-table-id rtb-PRIVATE \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-XXXXXXXXX
```

### 3. Performance Degradation
```bash
# Check ECS service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=universal-foundation-PROD-sign-service Name=ClusterName,Value=universal-foundation-PROD-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Maintenance Windows

### Planned Maintenance Steps
1. Scale service to minimum capacity during low-traffic periods
2. Update infrastructure (VPC endpoints, security groups)
3. Deploy new task definitions
4. Scale back to normal capacity
5. Monitor for 30 minutes post-deployment

### Zero-Downtime Deployments
- Use rolling deployments (ECS handles this automatically)
- Set deployment configuration: `maximumPercent: 200, minimumHealthyPercent: 100`
- Monitor ALB target health during deployments
