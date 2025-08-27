import { env } from 'process';

export const config = {
  // AWS Configuration
  awsRegion: env.AWS_REGION || 'us-east-1',
  
  // Service Configuration
  port: parseInt(env.PORT || '8080'),
  tenantId: env.TENANT_ID || 'T123',
  receiptsTable: env.RECEIPTS_TABLE || 'receipts',
  
  // Security
  sessionSecret: env.SESSION_SECRET,
  
  // Validation
  validate() {
    const required = ['AWS_REGION', 'RECEIPTS_TABLE'];
    const missing = required.filter(key => !env[key]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }
    
    // Warn if using access keys instead of IAM roles
    if (env.AWS_ACCESS_KEY_ID && env.AWS_SECRET_ACCESS_KEY) {
      console.warn('⚠️  Using AWS access keys. Consider using IAM roles for better security.');
    }
  }
};
