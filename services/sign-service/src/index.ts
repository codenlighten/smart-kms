import 'dotenv/config';
import express from 'express';
import { randomBytes, createHash } from 'crypto';
import { ulid } from 'ulid';
import { KMSProvider } from './cal/kmsProvider.js';
import { makePolicyEngine } from './policy/policyEngine.js';
import { putReceipt, getRecentReceipts } from './receipts/receiptStore.js';
import { canonicalize } from './util/jcs.js';
import { config } from './config.js';
import { apiKeyAuth, requireAdmin, validateTenantAccess } from './middleware/auth.js';

// Validate configuration on startup
config.validate();

const app = express();
app.use(express.json({ limit: '512kb' }));

// CORS for admin UI
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', 'http://localhost:3000');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

const PORT = process.env.PORT || 8080;
const TENANT_ID = config.tenantId;
const RECEIPTS_TABLE = config.receiptsTable;

const kms = new KMSProvider(config.awsRegion);
const policy = makePolicyEngine();

// Track service stats
const serviceStats = {
  startTime: Date.now(),
  requestCount: 0,
  signatureCount: 0,
  errorCount: 0
};

// Health check endpoints for load balancer (no auth required)
app.get('/health', (_req, res) => {
  serviceStats.requestCount++;
  res.status(200).json({ 
    status: 'healthy',
    service: 'smart-kms-sign-service',
    timestamp: new Date().toISOString(),
    uptime: Math.floor((Date.now() - serviceStats.startTime) / 1000)
  });
});

app.get('/v1/health', (_req, res) => {
  serviceStats.requestCount++;
  res.json({ 
    ok: true, 
    ts: new Date().toISOString(),
    uptime: Date.now() - serviceStats.startTime,
    stats: serviceStats
  });
});

// Admin endpoints (require authentication and admin permissions)
app.get('/v1/admin/stats', apiKeyAuth, requireAdmin, (_req, res) => {
  serviceStats.requestCount++;
  const uptime = Date.now() - serviceStats.startTime;
  res.json({
    totalKeys: 2, // T123 anchor + issue
    signaturesTotal: serviceStats.signatureCount,
    activeTenants: 1,
    avgResponseTime: 150, // Mock value
    requestCount: serviceStats.requestCount,
    errorCount: serviceStats.errorCount,
    uptime: Math.floor(uptime / 1000), // seconds
    requestsPerMin: Math.round((serviceStats.requestCount / (uptime / 60000)) || 0),
    errorRate: serviceStats.requestCount > 0 ? Math.round((serviceStats.errorCount / serviceStats.requestCount) * 100) : 0
  });
});

app.get('/v1/admin/keys', apiKeyAuth, requireAdmin, async (_req, res) => {
  serviceStats.requestCount++;
  try {
    res.json({
      keys: [
        {
          alias: 'alias/bsv/tenant/T123/anchor',
          keyId: '4d1451c6-d096-4b15-850b-98ab5c656548',
          usage: 'SIGN_VERIFY',
          curve: 'secp256k1',
          status: 'active'
        },
        {
          alias: 'alias/bsv/tenant/T123/issue',
          keyId: '44651bc8-bdf7-465c-8743-50b27851b653', 
          usage: 'SIGN_VERIFY',
          curve: 'secp256k1',
          status: 'active'
        }
      ]
    });
  } catch (err: any) {
    serviceStats.errorCount++;
    res.status(500).json({ error: 'server_error', message: err?.message });
  }
});

app.get('/v1/admin/recent-signatures', apiKeyAuth, requireAdmin, async (_req, res) => {
  serviceStats.requestCount++;
  try {
    const receipts = await getRecentReceipts(RECEIPTS_TABLE, 'TENANT#T123', 10);
    res.json({ signatures: receipts });
  } catch (err: any) {
    serviceStats.errorCount++;
    res.status(500).json({ error: 'server_error', message: err?.message });
  }
});

// Simplified signing endpoint for easy testing (requires authentication and tenant validation)
app.post('/v1/sign', apiKeyAuth, validateTenantAccess, async (req, res) => {
  serviceStats.requestCount++;
  try {
    const { tenant, keyId, message, algorithm } = req.body;
    
    // Validate required fields
    if (!tenant || !keyId || !message) {
      serviceStats.errorCount++;
      return res.status(400).json({ 
        error: 'missing_required_fields',
        message: 'tenant, keyId, and message are required' 
      });
    }

    // Create digest from message
    const messageBuffer = Buffer.from(message, 'utf8');
    const digest = createHash('sha256').update(messageBuffer).digest();
    const digestHex = digest.toString('hex');

    // Map tenant and keyId to KMS key reference
    const keyRef = `alias/bsv/tenant/${tenant}/${keyId}`;

    // Sign via KMS with VPC endpoint
    const { derHex, kid, requestId } = await kms.signDigest({
      keyRef,
      digestHex
    });

    // Create simplified response
    const response = {
      success: true,
      requestId,
      signature: {
        algorithm: algorithm || 'ECDSA_SHA_256',
        der: derHex,
        kid,
        keyRef
      },
      metadata: {
        tenant,
        keyId,
        messageDigest: digestHex,
        timestamp: new Date().toISOString()
      }
    };

    serviceStats.signatureCount++;
    res.json(response);

  } catch (err: any) {
    console.error('Signing error:', err);
    serviceStats.errorCount++;
    
    if (err.name === 'AccessDeniedException') {
      res.status(403).json({ 
        error: 'access_denied', 
        message: 'Not authorized to use this KMS key' 
      });
    } else if (err.name === 'NotFoundException') {
      res.status(404).json({ 
        error: 'key_not_found', 
        message: 'KMS key not found' 
      });
    } else {
      res.status(500).json({ 
        error: 'server_error', 
        message: err?.message || 'Internal server error' 
      });
    }
  }
});

// Legacy envelope-style signing endpoint (requires authentication)
app.post('/v1/sign/envelope', apiKeyAuth, async (req, res) => {
  serviceStats.requestCount++;
  try {
    const env = req.body;
    if (!env?.payload?.digestHex || !env?.payload?.keyRef) {
      serviceStats.errorCount++;
      return res.status(400).json({ error: 'digestHex and keyRef required' });
    }
    const actorTenant = env?.actor?.tenant;
    const idempotencyKey = env?.idempotencyKey;
    if (!actorTenant) {
      serviceStats.errorCount++;
      return res.status(400).json({ error: 'actor.tenant required' });
    }

    // Policy evaluation
    const decision = policy.evaluate({
      actor: env.actor,
      payload: env.payload
    });
    if (!decision.allow) {
      serviceStats.errorCount++;
      return res.status(403).json({ error: 'policy_block', reason: decision.reason });
    }

    const digestHex: string = env.payload.digestHex.toLowerCase();
    const keyRef: string = env.payload.keyRef;

    if (digestHex.length !== 64 || !/^[0-9a-f]+$/.test(digestHex)) {
      serviceStats.errorCount++;
      return res.status(400).json({ error: 'invalid digestHex' });
    }

    // Sign via KMS
    const { derHex, kid, requestId } = await kms.signDigest({
      keyRef,
      digestHex
    });

    // Build policy receipt
    const subjectId = ulid();
    const receipt = {
      schemaVersion: "1.0",
      policyVersion: "1.0",
      subject: { type: "GenericSign", id: subjectId, links: {} },
      inputs: { digest: digestHex, policyCtx: { tenant: actorTenant, keyRef } },
      sig: { alg: "ES256K", der: derHex, kid, keyRef },
      attest: {},
      anchors: { merkleRoot: null, bsvTxId: null },
      issuedAt: new Date().toISOString(),
      ext: { idempotencyKey, requestId }
    };

    await putReceipt(RECEIPTS_TABLE, `TENANT#${actorTenant}`, `RECEIPT#${subjectId}`, receipt);

    serviceStats.signatureCount++;
    res.json({
      requestId,
      policyReceipt: receipt,
      domainResult: { kid, keyRef }
    });
  } catch (err:any) {
    console.error(err);
    serviceStats.errorCount++;
    res.status(500).json({ error: 'server_error', message: err?.message });
  }
});

app.listen(PORT, () => {
  console.log(`sign-service listening on :${PORT}`);
});
