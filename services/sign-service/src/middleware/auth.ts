import { Request, Response, NextFunction } from 'express';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(client);

interface AuthenticatedRequest extends Request {
  tenant?: string;
  permissions?: string[];
}

export const apiKeyAuth = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const apiKey = req.headers['x-api-key'] as string;
  
  if (!apiKey) {
    return res.status(401).json({
      error: 'authentication_required',
      message: 'API key required in X-API-Key header'
    });
  }

  try {
    // Validate API key against DynamoDB
    const result = await dynamodb.send(new GetCommand({
      TableName: 'api-keys',
      Key: { apiKey }
    }));
    
    if (!result.Item || result.Item.status !== 'active') {
      return res.status(401).json({
        error: 'invalid_api_key',
        message: 'Invalid or inactive API key'
      });
    }

    // Add tenant and permissions to request
    req.tenant = result.Item.tenant;
    req.permissions = result.Item.role === 'admin' ? ['admin'] : ['user'];
    next();
    
  } catch (error) {
    console.error('Auth error:', error);
    return res.status(500).json({
      error: 'authentication_error',
      message: 'Failed to validate API key'
    });
  }
};

// Admin-only middleware
export const requireAdmin = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  if (!req.permissions?.includes('admin')) {
    return res.status(403).json({
      error: 'insufficient_permissions',
      message: 'Admin access required'
    });
  }
  next();
};

// Tenant isolation middleware
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
