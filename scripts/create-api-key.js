#!/usr/bin/env node

// API Key Management Script
// Usage: node create-api-key.js <tenant> [permissions]

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { randomBytes } from 'crypto';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(client);

async function createApiKey(tenant, permissions = ['sign']) {
  const apiKey = randomBytes(32).toString('hex');
  
  try {
    await dynamodb.send(new PutCommand({
      TableName: 'api-keys',
      Item: {
        apiKey,
        tenant,
        permissions,
        createdAt: Date.now(),
        expiresAt: Date.now() + (365 * 24 * 60 * 60 * 1000), // 1 year
        rateLimit: 100,
        description: `API key for tenant ${tenant}`
      }
    }));
    
    console.log(`✅ Created API key for tenant '${tenant}':`);
    console.log(`   API Key: ${apiKey}`);
    console.log(`   Permissions: ${permissions.join(', ')}`);
    console.log(`   Rate Limit: 100 requests/minute`);
    console.log(`   Expires: ${new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString()}`);
    console.log('');
    console.log('📋 Test with:');
    console.log(`   curl -H "X-API-Key: ${apiKey}" https://api.smartkms.com/v1/health`);
    
    return apiKey;
  } catch (error) {
    console.error('❌ Failed to create API key:', error);
    process.exit(1);
  }
}

// Parse command line arguments
const tenant = process.argv[2];
const permissions = process.argv[3] ? process.argv[3].split(',') : ['sign'];

if (!tenant) {
  console.log('Usage: node create-api-key.js <tenant> [permissions]');
  console.log('');
  console.log('Examples:');
  console.log('  node create-api-key.js PROD');
  console.log('  node create-api-key.js ADMIN sign,admin');
  console.log('  node create-api-key.js TEST_CLIENT sign');
  process.exit(1);
}

createApiKey(tenant, permissions);
