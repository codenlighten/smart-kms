# Universal Foundation (v1)

A small, stable core you can extend without breaking changes. Covers:
- Web3Keys/DID-friendly identity descriptors
- CAL (Crypto Abstraction Layer) with AWS KMS provider for secp256k1 (ES256K / ECDSA_SHA_256)
- Policy Receipts (signed + batch anchor-ready)
- Multi-tenant ready (per-tenant aliases, roles, prefixes)

## Layout
- `api/schemas/` – JSON schemas (additive)
- `services/sign-service/` – Node/TypeScript service exposing `/v1/sign` and `/v1/health`
- `infra/terraform/` – Terraform to provision KMS keys (anchor/issue), DynamoDB `receipts`, IAM role/policy, S3 bucket
- `examples/` – sample payloads & curl calls

## Quick start

1) **Provision AWS resources**
```bash
cd infra/terraform
terraform init
terraform apply -auto-approve   -var='project_name=universal-foundation'   -var='tenant_id=T123'   -var='create_artifacts_bucket=true'
```

Take note of outputs: `signer_role_arn`, `kms_anchor_alias`, `kms_issue_alias`, `receipts_table_name`, `artifacts_bucket`.

2) **Run the service**
```bash
cd services/sign-service
cp .env.example .env   # and set values
npm install
npm run build
npm start
```

3) **Sign a digest**
```bash
curl -s http://localhost:8080/v1/sign \
  -H 'content-type: application/json' \
  -d '{
    "idempotencyKey": "<module 'uuid' from '/usr/local/lib/python3.11/uuid.py'>",
    "schemaVersion": "1.0",
    "actor": {"did":"did:web:example.org/issuers/T123","tenant":"T123"},
    "payload": {
      "digestHex": "7f83b1657ff1fc53b92dc18148a1d65dfa1350cba0d7055f1b3a8a.....", 
      "keyRef": "${KMS_ANCHOR_ALIAS}"
    },
    "options": {"receiptOnly": true}
  }'
```

> **Note:** The service signs **digests** (`MessageType=DIGEST`). Canonicalize and hash payloads (JCS-like) on the client or use the helper endpoint (future).

## Extending
- Add new CAL providers under `src/cal/` (cloudhsm, webauthn, device)
- Add optional fields to schemas; never repurpose existing
- Add anchor worker implementation to broadcast hourly Merkle roots to BSV

(c) 2025-08-26
