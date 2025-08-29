#!/usr/bin/env node

/**
 * SmartKMS Demo Application
 * 
 * This demonstrates how to integrate your AWS KMS Scaffold
 * with various types of applications.
 */

const axios = require('axios');
const crypto = require('crypto');
const fs = require('fs');

class SmartKMSClient {
  constructor(baseUrl = 'https://api.smartkms.com/v1') {
    this.baseUrl = baseUrl;
    this.tenant = 'PROD'; // Your actual production tenant
  }

  async signData(data, keyAlias = 'anchor') {
    console.log(`🔐 Signing data with ${keyAlias} key...`);
    
    // Hash the data with SHA-256
    const hash = crypto.createHash('sha256').update(data).digest('hex');
    console.log(`📝 SHA-256 Hash: ${hash}`);
    
    const request = {
      idempotencyKey: crypto.randomUUID(),
      schemaVersion: '1.0',
      actor: { 
        tenant: this.tenant,
        did: `did:web:smartkms.com/tenants/${this.tenant}`
      },
      payload: {
        digestHex: hash,
        keyRef: `alias/bsv/tenant/${this.tenant}/${keyAlias}`
      }
    };

    try {
      const response = await axios.post(`${this.baseUrl}/sign`, request);
      console.log(`✅ Signature created: ${response.data.policyReceipt.sig.der.substring(0, 20)}...`);
      return response.data;
    } catch (error) {
      console.error(`❌ Signing failed:`, error.response?.data || error.message);
      throw error;
    }
  }

  async getHealth() {
    const response = await axios.get(`${this.baseUrl}/health`);
    return response.data;
  }

  async getStats() {
    const response = await axios.get(`${this.baseUrl}/admin/stats`);
    return response.data;
  }
}

// Demo 1: Basic Message Signing
async function demoMessageSigning() {
  console.log('\n🚀 Demo 1: Basic Message Signing');
  console.log('================================');
  
  const kms = new SmartKMSClient();
  
  const message = "Hello from SmartKMS! This is a test message.";
  console.log(`Message: "${message}"`);
  
  const result = await kms.signData(message);
  
  console.log('\n📋 Signing Result:');
  console.log(`- Algorithm: ${result.policyReceipt.sig.alg}`);
  console.log(`- Key Reference: ${result.policyReceipt.sig.keyRef}`);
  console.log(`- Signature (DER): ${result.policyReceipt.sig.der}`);
  console.log(`- Issued At: ${result.policyReceipt.issuedAt}`);
  
  return result;
}

// Demo 2: File Signing
async function demoFileSigning() {
  console.log('\n📄 Demo 2: File Signing');
  console.log('========================');
  
  const kms = new SmartKMSClient();
  
  // Create a temporary file to sign
  const fileContent = `SmartKMS Test Document
Created: ${new Date().toISOString()}
Content: This is a test document for digital signing demonstration.
---
This document is signed with AWS KMS for authenticity verification.`;
  
  const tempFile = '/tmp/test-document.txt';
  fs.writeFileSync(tempFile, fileContent);
  console.log(`📝 Created test file: ${tempFile}`);
  
  // Read and sign the file
  const fileBuffer = fs.readFileSync(tempFile);
  const result = await kms.signData(fileBuffer);
  
  console.log('\n📋 File Signing Result:');
  console.log(`- File Size: ${fileBuffer.length} bytes`);
  console.log(`- SHA-256: ${crypto.createHash('sha256').update(fileBuffer).digest('hex')}`);
  console.log(`- Signature: ${result.policyReceipt.sig.der.substring(0, 40)}...`);
  
  // Clean up
  fs.unlinkSync(tempFile);
  
  return result;
}

// Demo 3: BSV Transaction Simulation
async function demoBSVTransaction() {
  console.log('\n⛓️  Demo 3: BSV Transaction Signing Simulation');
  console.log('==============================================');
  
  const kms = new SmartKMSClient();
  
  // Simulate a BSV transaction (simplified)
  const mockTx = {
    version: 1,
    inputs: [
      {
        txid: "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        vout: 0,
        scriptSig: "",
        sequence: 0xffffffff
      }
    ],
    outputs: [
      {
        value: 100000, // 0.001 BSV in satoshis
        scriptPubKey: "76a914..." // Mock P2PKH script
      }
    ],
    locktime: 0
  };
  
  console.log('🔗 Mock BSV Transaction:', JSON.stringify(mockTx, null, 2));
  
  // In a real implementation, you'd serialize this properly
  const txString = JSON.stringify(mockTx);
  const result = await kms.signData(txString, 'anchor');
  
  console.log('\n📋 Transaction Signing Result:');
  console.log(`- Transaction Hash: ${crypto.createHash('sha256').update(txString).digest('hex')}`);
  console.log(`- Signature: ${result.policyReceipt.sig.der}`);
  console.log(`- Key Used: ${result.policyReceipt.sig.keyRef}`);
  
  return result;
}

// Demo 4: API Token Creation
async function demoAPIToken() {
  console.log('\n🎫 Demo 4: API Token Creation');
  console.log('==============================');
  
  const kms = new SmartKMSClient();
  
  // Create a JWT-like payload
  const payload = {
    iss: 'smartkms.com',
    sub: 'user123',
    aud: 'my-application',
    exp: Math.floor(Date.now() / 1000) + 3600, // 1 hour
    iat: Math.floor(Date.now() / 1000),
    scope: ['read', 'write'],
    tenant: 'PROD'
  };
  
  console.log('🎭 Token Payload:', JSON.stringify(payload, null, 2));
  
  // Sign the payload
  const result = await kms.signData(JSON.stringify(payload), 'issue');
  
  // Create a simple signed token format
  const token = {
    payload: payload,
    signature: result.policyReceipt.sig.der,
    algorithm: result.policyReceipt.sig.alg,
    keyId: result.policyReceipt.sig.kid
  };
  
  console.log('\n🎫 Signed Token:');
  console.log(JSON.stringify(token, null, 2));
  
  return token;
}

// Demo 5: System Health Check
async function demoHealthCheck() {
  console.log('\n🏥 Demo 5: System Health Check');
  console.log('===============================');
  
  const kms = new SmartKMSClient();
  
  const health = await kms.getHealth();
  const stats = await kms.getStats();
  
  console.log('🔍 Health Status:');
  console.log(`- Service OK: ${health.ok ? '✅' : '❌'}`);
  console.log(`- Uptime: ${Math.round(health.uptime / 1000 / 60)} minutes`);
  console.log(`- Total Requests: ${health.stats.requestCount.toLocaleString()}`);
  console.log(`- Error Count: ${health.stats.errorCount}`);
  
  console.log('\n📊 Detailed Statistics:');
  console.log(`- Total Keys: ${stats.totalKeys}`);
  console.log(`- Active Tenants: ${stats.activeTenants}`);
  console.log(`- Average Response Time: ${stats.avgResponseTime}ms`);
  console.log(`- Requests Per Minute: ${stats.requestsPerMin}`);
  console.log(`- Error Rate: ${stats.errorRate}%`);
  
  return { health, stats };
}

// Main demo runner
async function runAllDemos() {
  console.log('🎯 SmartKMS Integration Demos');
  console.log('==============================');
  console.log('This demonstrates how to integrate your AWS KMS Scaffold with applications.');
  
  try {
    await demoHealthCheck();
    await demoMessageSigning();
    await demoFileSigning();
    await demoBSVTransaction();
    await demoAPIToken();
    
    console.log('\n🎉 All demos completed successfully!');
    console.log('\nYour SmartKMS service is ready for production integration.');
    console.log('Use the patterns above to integrate with your applications.');
    
  } catch (error) {
    console.error('\n❌ Demo failed:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  runAllDemos();
}

module.exports = {
  SmartKMSClient,
  demoMessageSigning,
  demoFileSigning,
  demoBSVTransaction,
  demoAPIToken,
  demoHealthCheck
};
