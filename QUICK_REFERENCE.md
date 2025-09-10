# Smart KMS - Quick Reference Card

## 🚀 **Essential Information**

**Production API**: `https://api.smartkms.com/v1`  
**Status**: ✅ Operational (99.2% uptime)  
**Keys**: `anchor` and `issue` for tenant `PROD`  

## 📞 **Quick API Calls**

### Health Check
```bash
curl https://api.smartkms.com/v1/health
```

### Sign Message
```bash
curl -X POST https://api.smartkms.com/v1/sign \
  -H "Content-Type: application/json" \
  -d '{"tenant":"PROD","keyId":"anchor","message":"Hello World"}'
```

### Get Stats
```bash
curl https://api.smartkms.com/v1/admin/stats
```

## 🔧 **Development**

### Local Setup
```bash
cd services/sign-service && npm install && npm start
cd admin-ui && npm install && npm run dev
```

### Test Examples
```bash
cd examples && node demo-smart-kms.js
```

## 📚 **Documentation**

- **Complete Guide**: [TEAM_DOCUMENTATION.md](TEAM_DOCUMENTATION.md)
- **API Reference**: [DEVELOPER_API_GUIDE.md](DEVELOPER_API_GUIDE.md)
- **Current Status**: [PROJECT_STATUS.md](PROJECT_STATUS.md)

## 🆘 **Support**

**Production Issues**: On-call rotation  
**Development**: #smart-kms Slack  
**Documentation**: GitHub Issues  

## 🏗️ **Infrastructure**

**Platform**: AWS ECS Fargate  
**Region**: us-east-1  
**Cost**: ~$70-100/month  
**Resources**: 45 AWS resources  

---
*Keep this card handy for quick reference!*
