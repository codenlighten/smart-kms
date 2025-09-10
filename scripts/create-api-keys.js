#!/usr/bin/env node

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const crypto = require('crypto');

// Configuration
const AWS_REGION = 'us-east-1';
const TABLE_NAME = 'api-keys';

// Initialize DynamoDB client
const dynamoClient = new DynamoDBClient({ region: AWS_REGION });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

// Helper function to generate a secure API key
function generateApiKey() {
  return crypto.randomBytes(32).toString('hex');
}

// Function to create an API key
async function createApiKey(tenant, role = 'user', description = '') {
  const apiKey = generateApiKey();
  const now = new Date().toISOString();
  
  const item = {
    apiKey: apiKey,
    tenant: tenant,
    role: role,
    description: description,
    createdAt: now,
    lastUsed: null,
    status: 'active'
  };

  try {
    await docClient.send(new PutCommand({
      TableName: TABLE_NAME,
      Item: item
    }));
    
    console.log(`✅ Created ${role} API key for tenant ${tenant}:`);
    console.log(`   API Key: ${apiKey}`);
    console.log(`   Description: ${description}`);
    console.log('');
    
    return apiKey;
  } catch (error) {
    console.error(`❌ Failed to create API key for tenant ${tenant}:`, error);
    throw error;
  }
}

// Main function to create initial API keys
async function main() {
  console.log('🔑 Creating initial API keys for Smart KMS...\n');
  
  try {
    // Create admin API key for PROD tenant
    await createApiKey('PROD', 'admin', 'Production admin key for Smart KMS management');
    
    // Create user API key for PROD tenant
    await createApiKey('PROD', 'user', 'Production user key for Smart KMS signing operations');
    
    // Create admin API key for TEST tenant (if needed)
    await createApiKey('TEST', 'admin', 'Test admin key for Smart KMS development');
    
    // Create user API key for TEST tenant (if needed)
    await createApiKey('TEST', 'user', 'Test user key for Smart KMS development');
    
    console.log('🎉 All API keys created successfully!');
    console.log('\n⚠️  SECURITY NOTICE:');
    console.log('   - Store these API keys securely');
    console.log('   - Use admin keys only for administrative operations');
    console.log('   - Use user keys for signing operations');
    console.log('   - Include API keys in the X-API-Key header for all requests');
    
  } catch (error) {
    console.error('❌ Failed to create API keys:', error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { createApiKey, generateApiKey };
