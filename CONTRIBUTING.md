# Contributing to SmartKMS

Thanks for helping build an enterprise-ready signing platform!

## Ground Rules
- By contributing, you agree your code is under **Apache-2.0**.
- All PRs require passing CI and at least one maintainer approval.
- Add/adjust tests for any functional change.

## Dev Setup
```bash
# Sign Service
cd services/sign-service
npm i
npm run build
npm test
npm start

# Admin UI
cd ../../admin-ui
npm i
npm run dev
```

## Testing

* Unit tests: `npm test`
* Add integration tests using LocalStack/Testcontainers if touching AWS calls.
* Keep endpoints in sync with `docs/openapi.yaml`.

## Commit & PR

* Conventional commits preferred (feat:, fix:, docs:, chore:)
* Link issues in PR descriptions.
