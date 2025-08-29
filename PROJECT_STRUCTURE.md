# Smart KMS Project Structure

## 📁 Core Project Files
```
├── README.md                 # Main project documentation
├── LICENSE                   # Apache 2.0 license
├── CONTRIBUTING.md           # Contribution guidelines
├── SECURITY.md              # Security best practices
├── DOCUMENTATION.md         # Complete technical documentation
├── .gitignore              # Git ignore patterns
├── .env.example            # Environment template
└── package.json            # Root project configuration
```

## 🏗️ Infrastructure
```
├── infra/terraform/        # AWS infrastructure as code
├── modules/               # Reusable Terraform modules
└── scripts/deploy.sh      # Deployment automation
```

## 🔐 Core Services
```
├── services/sign-service/  # Main KMS signing service
│   ├── src/               # TypeScript source code
│   ├── Dockerfile         # Container configuration
│   └── package.json       # Service dependencies
└── admin-ui/              # Vue.js admin dashboard
```

## 📋 API & Documentation
```
├── api/schemas/           # JSON Schema definitions
├── docs/                  # Additional documentation
└── examples/              # Integration examples & demos
```

## 🧪 Examples & Testing
```
examples/
├── integration-demo.js    # Integration examples
├── real-kms-demo.js      # KMS signature demonstration
├── test-smart-kms.js     # API testing script
└── variables.tf          # Example Terraform variables
```

## 🔄 Key Features
- ✅ Multi-tenant KMS signing (PROD/DEV/TEST)
- ✅ Hardware-backed security (AWS KMS HSM)
- ✅ ECS Fargate deployment with auto-scaling
- ✅ VPC endpoints for secure connectivity
- ✅ SSL-terminated load balancer
- ✅ Real-time monitoring dashboard
- ✅ Complete integration documentation
