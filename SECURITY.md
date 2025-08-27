# Security Guidelines

## AWS Credentials Management

### Current Status
- ✅ `.env` file is now properly gitignored
- ✅ `.env.example` template created
- ⚠️  **Action Required**: Rotate the AWS keys currently in `.env`

### Recommended Authentication Methods (in order of preference):

#### 1. **IAM Roles (Recommended for Production)**
```bash
# Use IAM roles when running on EC2, ECS, Lambda, etc.
# No credentials needed in .env file
AWS_REGION=us-east-1
```

#### 2. **AWS CLI Profiles (Development)**
```bash
# Use AWS CLI profiles for development
aws configure --profile your-project
export AWS_PROFILE=your-project
```

#### 3. **Environment Variables (Last Resort)**
```bash
# Only for development/testing
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_REGION=us-east-1
```

## Security Checklist

### Immediate Actions
- [ ] Rotate AWS access keys in `.env`
- [ ] Verify `.env` is not in git history: `git log --oneline .env`
- [ ] If `.env` was committed, consider it compromised and rotate keys immediately

### Production Deployment
- [ ] Use IAM roles instead of access keys
- [ ] Enable AWS CloudTrail for audit logging
- [ ] Set up AWS Config for compliance monitoring
- [ ] Implement least-privilege IAM policies
- [ ] Enable KMS key rotation
- [ ] Set up monitoring and alerting

### Application Security
- [ ] Implement rate limiting
- [ ] Add request correlation IDs
- [ ] Set up structured logging
- [ ] Add input validation middleware
- [ ] Implement circuit breakers for AWS calls
- [ ] Add health checks for dependencies

## Environment Variables Reference

### Required
- `AWS_REGION` - AWS region for resources
- `RECEIPTS_TABLE` - DynamoDB table name
- `TENANT_ID` - Default tenant identifier

### Optional
- `PORT` - Service port (default: 8080)
- `SESSION_SECRET` - Session encryption key
- `AWS_ACCESS_KEY_ID` - AWS access key (prefer IAM roles)
- `AWS_SECRET_ACCESS_KEY` - AWS secret key (prefer IAM roles)

## IAM Policy Example

For production, create an IAM role with minimal permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Sign",
        "kms:GetPublicKey"
      ],
      "Resource": "arn:aws:kms:*:*:key/*",
      "Condition": {
        "StringLike": {
          "kms:ViaService": "kms.*.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/receipts"
    }
  ]
}
```
