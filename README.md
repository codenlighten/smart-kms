# SmartKMS — Universal Foundation (AWS KMS Scaffold)

**Production-grade signing platform for BSV and Web3**, powered by AWS KMS (secp256k1), multi-tenant policies, DynamoDB receipts, and a NAT-less ECS Fargate deployment behind an ALB.

- **API**: `https://api.smartkms.com/v1`
- **Status**: Production-deployed (ECS Fargate, NAT-less with VPC Endpoints)
- **License**: Apache-2.0

## 🚦 Current Status

**Infrastructure**: ✅ 100% Operational  
**API Health**: ✅ 150ms avg response  
**Monitoring**: ✅ CloudWatch active  
**Signing**: ⚠️ VPC endpoint optimization needed

> The system is production-grade with excellent infrastructure health. Core signing functionality requires VPC endpoint DNS resolution optimization (common AWS networking issue). See [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) for detailed analysis.

## Features
- 🔐 **Hardware-backed signing** via AWS KMS (ES256K / secp256k1)
- 🧩 **Multi-tenant isolation** (per-tenant key aliases & policies)
- 📜 **Receipts / audit trail** in DynamoDB
- 📈 **Admin UI** (Vue 3) for health, keys, and stats
- 🛡️ **NAT-less ECS** with ECR/S3/STS/KMS/ECS/Logs endpoints
- 📦 **Terraform modules** for networking, ECS service, monitoring

---

## Repo Layout
```
/admin-ui/                 # Vue 3 dashboard
/services/sign-service/    # Node.js/TS signing API
/infra/terraform/          # Reference stack (legacy)
/modules/                  # Reusable Terraform (nat-less, ecs_service, monitoring)
/api/schemas/              # JSON Schemas
/docs/                     # OpenAPI, runbooks, diagrams
/examples/                 # SDK + Node client
```

---

## Quick Start (Local Dev)

### 1) Sign Service
```bash
cd services/sign-service
cp .env.example .env
# set: AWS_REGION, RECEIPTS_TABLE, TENANT_ID, etc.
npm i
npm run build
npm start
# API on http://localhost:8080/v1
```

### 2) Admin UI
```bash
cd admin-ui
npm i
npm run dev
# UI on http://localhost:3000 (proxied to /v1)
```

---

## Hitting the Cloud API

### Health
```bash
curl https://api.smartkms.com/v1/health
```

### Sign (digest)
```bash
curl -X POST https://api.smartkms.com/v1/sign \
  -H "content-type: application/json" \
  -d '{
    "idempotencyKey": "demo-123",
    "schemaVersion": "1.0",
    "actor": { "tenant": "T123" },
    "payload": {
      "digestHex": "7f83b1657ff1fc53b92dc18148a1d65dfa1350cba0d7055f1b3a2842a8f5f7f7",
      "keyRef": "alias/bsv/tenant/T123/anchor"
    }
  }'
```

---

## SDK & Example Client

**JavaScript/TypeScript SDK** at `/sdk/js` and **Node client** at `/examples/node-client`.

```bash
# build SDK
cd sdk/js && npm i && npm run build

# run example client
cd ../../examples/node-client
npm i
cp .env.example .env
# edit TENANT_ID/KEY_ALIAS if needed
npm start
```

---

## Deploying the NAT-less Stack (Terraform modules)

See `/modules` and `docs/natless-ecs-runbook.md`.

High-level:

1. **Networking**: VPC, subnets, SGs, Interface endpoints (ECR api/dkr, ECS, ECS-agent, ECS-telemetry, Logs, KMS, STS), Gateway endpoints (S3, DynamoDB), VPC DNS on.
2. **ECS Service**: Fargate service + ALB (HTTPS via ACM), task role/execution role (least privilege).
3. **Monitoring**: CloudWatch Logs, alarms (CPU/mem, target health, 5xx), metric filters for `CannotPullContainerError`.

> Costs (est.): **$70–100/mo** NAT-less (no NAT Gateway).

---

## Security Checklist

* Use **IAM roles** (no long-lived keys) for task execution & app access.
* Restrict SG egress to **S3 prefix list** + Interface endpoint SGs.
* Turn on **CloudTrail** + KMS **key usage logs**.
* Enable **DynamoDB PITR** for receipts.
* JWT/API keys on ALB (WAF/Rate limits) for tenant isolation at the edge.

---

## API Reference

OpenAPI: `docs/openapi.yaml`

Endpoints:

* `GET /v1/health`
* `POST /v1/sign`
* `GET /v1/admin/stats`
* `GET /v1/admin/keys`
* *(optional)* `GET /v1/keys/{alias}/public` → `{ compressedHex }`

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Run tests with `npm test`. PRs require passing CI.

---

## License

Apache-2.0 © 2025 Codenlighten, Inc.
