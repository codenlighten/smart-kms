# Smart KMS Security Implementation Plan
*Securing the Hardware-Backed Signing Service*

## 🚨 **Current Security Assessment**

### **Vulnerabilities Identified**
- ❌ **No Authentication**: Anyone can access all endpoints
- ❌ **No Authorization**: No tenant isolation or role-based access
- ❌ **No Rate Limiting**: Service vulnerable to abuse
- ❌ **No API Keys**: No way to identify or control callers
- ❌ **Admin Endpoints Exposed**: Sensitive operations publicly accessible

### **Risk Level**: 🔴 **CRITICAL** - Immediate action required

---

## 🛡️ **Recommended Security Architecture**

### **Phase 1: Immediate Security (Quick Wins)**

#### 1. API Key Authentication
```typescript
// Add to services/sign-service/src/middleware/auth.ts
import { Request, Response, NextFunction } from 'express';

interface AuthenticatedRequest extends Request {
  tenant?: string;
  permissions?: string[];
}

export const apiKeyAuth = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const apiKey = req.headers['x-api-key'] || req.headers['authorization']?.replace('Bearer ', '');
  
  if (!apiKey) {
    return res.status(401).json({
      error: 'authentication_required',
      message: 'API key required in X-API-Key header'
    });
  }

  try {
    // Validate API key against DynamoDB table
    const keyData = await validateApiKey(apiKey);
    
    if (!keyData) {
      return res.status(401).json({
        error: 'invalid_api_key',
        message: 'Invalid or expired API key'
      });
    }

    // Add tenant and permissions to request
    req.tenant = keyData.tenant;
    req.permissions = keyData.permissions;
    next();
    
  } catch (error) {
    return res.status(500).json({
      error: 'authentication_error',
      message: 'Failed to validate API key'
    });
  }
};

// Validate API key function
async function validateApiKey(apiKey: string) {
  // Query DynamoDB api-keys table
  const params = {
    TableName: 'api-keys',
    Key: { apiKey }
  };
  
  const result = await dynamoDB.get(params).promise();
  
  if (!result.Item || result.Item.expiresAt < Date.now()) {
    return null;
  }
  
  return {
    tenant: result.Item.tenant,
    permissions: result.Item.permissions || [],
    rateLimit: result.Item.rateLimit || 100
  };
}
```

#### 2. Admin Endpoint Protection
```typescript
// Add admin-only middleware
export const requireAdmin = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  if (!req.permissions?.includes('admin')) {
    return res.status(403).json({
      error: 'insufficient_permissions',
      message: 'Admin access required'
    });
  }
  next();
};

// Apply to admin routes
app.get('/v1/admin/keys', apiKeyAuth, requireAdmin, getKeys);
app.get('/v1/admin/stats', apiKeyAuth, requireAdmin, getStats);
app.get('/v1/admin/recent-signatures', apiKeyAuth, requireAdmin, getRecentSignatures);
```

#### 3. Tenant Isolation
```typescript
// Enforce tenant isolation in signing
export const validateTenantAccess = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const requestedTenant = req.body.tenant;
  
  if (requestedTenant !== req.tenant) {
    return res.status(403).json({
      error: 'tenant_access_denied',
      message: `Access denied for tenant: ${requestedTenant}`
    });
  }
  next();
};

// Apply to signing endpoint
app.post('/v1/sign', apiKeyAuth, validateTenantAccess, signMessage);
```

### **Phase 2: Enhanced Security (Production Ready)**

#### 1. JWT Token Authentication
```typescript
// JWT-based authentication with short-lived tokens
import jwt from 'jsonwebtoken';

export const jwtAuth = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const token = req.headers['authorization']?.replace('Bearer ', '');
  
  if (!token) {
    return res.status(401).json({
      error: 'token_required',
      message: 'JWT token required'
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
    
    req.tenant = decoded.tenant;
    req.permissions = decoded.permissions;
    next();
    
  } catch (error) {
    return res.status(401).json({
      error: 'invalid_token',
      message: 'Invalid or expired token'
    });
  }
};

// Token endpoint for API key exchange
app.post('/v1/auth/token', async (req, res) => {
  const { apiKey } = req.body;
  
  const keyData = await validateApiKey(apiKey);
  if (!keyData) {
    return res.status(401).json({ error: 'invalid_api_key' });
  }
  
  const token = jwt.sign(
    { 
      tenant: keyData.tenant,
      permissions: keyData.permissions 
    },
    process.env.JWT_SECRET!,
    { expiresIn: '1h' }
  );
  
  res.json({ token, expiresIn: 3600 });
});
```

#### 2. Rate Limiting by Tenant
```typescript
// Implement Redis-based rate limiting
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';

const createRateLimiter = (windowMs: number, max: number) => {
  return rateLimit({
    store: new RedisStore({
      client: redisClient,
      prefix: 'smart-kms-rate-limit:'
    }),
    windowMs,
    max,
    keyGenerator: (req: AuthenticatedRequest) => {
      return `${req.tenant}:${req.ip}`;
    },
    message: {
      error: 'rate_limit_exceeded',
      message: 'Too many requests, please try again later'
    }
  });
};

// Apply different limits to different endpoints
app.use('/v1/sign', createRateLimiter(60 * 1000, 30)); // 30/minute for signing
app.use('/v1/admin', createRateLimiter(60 * 1000, 10)); // 10/minute for admin
```

#### 3. Request Signing for High Security
```typescript
// HMAC signature verification for critical operations
import crypto from 'crypto';

export const verifyRequestSignature = (req: Request, res: Response, next: NextFunction) => {
  const signature = req.headers['x-signature'] as string;
  const timestamp = req.headers['x-timestamp'] as string;
  
  if (!signature || !timestamp) {
    return res.status(401).json({
      error: 'signature_required',
      message: 'Request signature and timestamp required'
    });
  }
  
  // Check timestamp (prevent replay attacks)
  const requestTime = parseInt(timestamp);
  const now = Date.now();
  if (Math.abs(now - requestTime) > 300000) { // 5 minutes
    return res.status(401).json({
      error: 'request_expired',
      message: 'Request timestamp too old'
    });
  }
  
  // Verify signature
  const payload = JSON.stringify(req.body) + timestamp;
  const expectedSignature = crypto
    .createHmac('sha256', req.tenant + process.env.SIGNING_SECRET!)
    .update(payload)
    .digest('hex');
  
  if (signature !== expectedSignature) {
    return res.status(401).json({
      error: 'invalid_signature',
      message: 'Request signature verification failed'
    });
  }
  
  next();
};
```

---

## 🗄️ **Required Infrastructure Changes**

### 1. API Keys Table (DynamoDB)
```terraform
# Add to infra/terraform/dynamodb.tf
resource "aws_dynamodb_table" "api_keys" {
  name           = "api-keys"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "apiKey"

  attribute {
    name = "apiKey"
    type = "S"
  }

  attribute {
    name = "tenant"
    type = "S"
  }

  global_secondary_index {
    name            = "tenant-index"
    hash_key        = "tenant"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}
```

### 2. Enhanced IAM Permissions
```terraform
# Update infra/terraform/iam.tf
resource "aws_iam_policy" "signer_policy" {
  name = "${local.name_prefix}-signer-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["kms:Sign","kms:GetPublicKey","kms:DescribeKey"],
        Resource = [
          aws_kms_key.anchor.arn,
          aws_kms_key.issue.arn
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["dynamodb:PutItem", "dynamodb:Query", "dynamodb:Scan"],
        Resource = aws_dynamodb_table.receipts.arn
      },
      {
        Effect   = "Allow",
        Action   = ["dynamodb:GetItem", "dynamodb:Query"],
        Resource = aws_dynamodb_table.api_keys.arn
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
        Resource = "*"
      }
    ]
  })
}
```

### 3. Redis for Rate Limiting
```terraform
# Add to infra/terraform/redis.tf
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id]
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id         = "${local.name_prefix}-redis"
  description                  = "Redis for Smart KMS rate limiting"
  
  node_type                    = "cache.t3.micro"
  port                         = 6379
  parameter_group_name         = "default.redis7"
  
  num_cache_clusters           = 2
  automatic_failover_enabled   = true
  multi_az_enabled            = true
  
  subnet_group_name           = aws_elasticache_subnet_group.redis.name
  security_group_ids          = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true
  
  tags = local.common_tags
}
```

---

## 🔧 **Implementation Steps**

### **Step 1: Immediate Lockdown (Today)**
```bash
# 1. Add environment variables
export JWT_SECRET="your-super-secret-jwt-key"
export SIGNING_SECRET="your-request-signing-secret"

# 2. Create API keys table
cd infra/terraform
terraform apply -target=aws_dynamodb_table.api_keys

# 3. Deploy authentication middleware
cd ../../services/sign-service
npm install jsonwebtoken express-rate-limit rate-limit-redis
```

### **Step 2: Create Initial API Keys**
```javascript
// Script to create initial API keys
const AWS = require('aws-sdk');
const crypto = require('crypto');

const dynamodb = new AWS.DynamoDB.DocumentClient();

async function createApiKey(tenant, permissions = []) {
  const apiKey = crypto.randomBytes(32).toString('hex');
  
  await dynamodb.put({
    TableName: 'api-keys',
    Item: {
      apiKey,
      tenant,
      permissions,
      createdAt: Date.now(),
      expiresAt: Date.now() + (365 * 24 * 60 * 60 * 1000), // 1 year
      rateLimit: 100
    }
  }).promise();
  
  console.log(`Created API key for ${tenant}: ${apiKey}`);
  return apiKey;
}

// Create keys for your tenants
createApiKey('PROD', ['sign']);
createApiKey('ADMIN', ['sign', 'admin']);
```

### **Step 3: Update Application Code**
```typescript
// services/sign-service/src/index.ts
import express from 'express';
import { apiKeyAuth, requireAdmin, validateTenantAccess } from './middleware/auth';

const app = express();

// Public endpoints (no auth required)
app.get('/v1/health', healthCheck);

// Authentication endpoint
app.post('/v1/auth/token', authenticateApiKey);

// Protected signing endpoint
app.post('/v1/sign', apiKeyAuth, validateTenantAccess, signMessage);

// Admin endpoints (require admin permissions)
app.get('/v1/admin/keys', apiKeyAuth, requireAdmin, getKeys);
app.get('/v1/admin/stats', apiKeyAuth, requireAdmin, getStats);
app.get('/v1/admin/recent-signatures', apiKeyAuth, requireAdmin, getRecentSignatures);
```

### **Step 4: Update Documentation**
```bash
# Update API guide with authentication examples
curl -X POST https://api.smartkms.com/v1/sign \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key-here" \
  -d '{"tenant":"PROD","keyId":"anchor","message":"test"}'
```

---

## 🔍 **Security Monitoring**

### **CloudWatch Alarms**
```terraform
# Add security monitoring alarms
resource "aws_cloudwatch_metric_alarm" "failed_auth_attempts" {
  alarm_name          = "${local.name_prefix}-failed-auth-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FailedAuthAttempts"
  namespace           = "SmartKMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors failed authentication attempts"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "unusual_signing_activity" {
  alarm_name          = "${local.name_prefix}-unusual-signing-activity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SigningRequests"
  namespace           = "SmartKMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000"
  alarm_description   = "This metric monitors unusual signing activity"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### **Security Logging**
```typescript
// Enhanced logging for security events
import winston from 'winston';

const securityLogger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.CloudWatchLogs({
      logGroupName: '/aws/ecs/smart-kms-security',
      logStreamName: 'security-events'
    })
  ]
});

// Log security events
export const logSecurityEvent = (event: string, details: any) => {
  securityLogger.info('SECURITY_EVENT', {
    event,
    ...details,
    timestamp: new Date().toISOString()
  });
};
```

---

## ⚡ **Quick Emergency Lockdown**

If you need to immediately secure the service:

```bash
# 1. Add IP whitelisting to ALB security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-your-alb-security-group \
  --protocol tcp \
  --port 443 \
  --cidr your.office.ip/32

# 2. Temporarily revoke public access
aws ec2 revoke-security-group-ingress \
  --group-id sg-your-alb-security-group \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

---

## 📋 **Security Implementation Checklist**

### **Phase 1 - Immediate (This Week)**
- [ ] Create API keys DynamoDB table
- [ ] Implement API key authentication middleware
- [ ] Protect admin endpoints with permissions
- [ ] Add tenant isolation validation
- [ ] Create initial API keys for your team
- [ ] Update documentation with auth examples

### **Phase 2 - Enhanced (Next 2 Weeks)**
- [ ] Implement JWT token authentication
- [ ] Add Redis-based rate limiting
- [ ] Set up request signing for critical operations
- [ ] Create security monitoring dashboards
- [ ] Implement security event logging
- [ ] Add automated security testing

### **Phase 3 - Advanced (Next Month)**
- [ ] Implement OAuth 2.0 / OIDC integration
- [ ] Add API versioning and deprecation policies
- [ ] Set up automated penetration testing
- [ ] Implement zero-trust network architecture
- [ ] Add compliance reporting automation

---

## 💰 **Cost Impact**

### **Additional AWS Costs**
- **DynamoDB API Keys Table**: ~$1-5/month
- **Redis Cache**: ~$15-30/month (t3.micro)
- **CloudWatch Logs**: ~$5-10/month
- **Total Additional Cost**: ~$20-45/month

### **Security ROI**
- **Prevents unauthorized usage**: Could save $1000s in AWS KMS costs
- **Compliance readiness**: Enables enterprise sales
- **Reduced liability**: Protects against security breaches

---

This security implementation will transform your Smart KMS from an open service to an enterprise-grade, secure cryptographic platform. The phased approach allows you to implement critical security measures immediately while building toward a comprehensive security architecture.

Would you like me to help implement any of these security measures right away?
