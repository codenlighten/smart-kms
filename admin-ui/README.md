# Universal Foundation Admin UI

A modern, responsive admin dashboard for managing the Universal Foundation AWS KMS scaffold.

## Features

- **Real-time Service Monitoring** - Live health checks and system status
- **KMS Key Management** - View and monitor active cryptographic keys
- **Signature Analytics** - Track signing operations and performance metrics
- **Test Interface** - Built-in signature testing capabilities
- **Tenant Management** - Multi-tenant oversight and analytics

## Tech Stack

- **Vue 3** with Composition API
- **TypeScript** for type safety
- **Tailwind CSS** for modern styling
- **Heroicons** for consistent iconography
- **Vite** for fast development and building

## Quick Start

### Prerequisites

- Node.js 18+ 
- Universal Foundation sign-service running on port 8080

### Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

The admin UI will be available at `http://localhost:3000`

### Production Build

```bash
# Build for production
npm run build

# Preview production build
npm run preview
```

## API Integration

The admin UI connects to the sign-service backend via proxy configuration:

- Health checks: `GET /v1/health`
- Admin stats: `GET /v1/admin/stats`
- KMS keys: `GET /v1/admin/keys`
- Recent signatures: `GET /v1/admin/recent-signatures`
- Test signing: `POST /v1/sign`

## Features Overview

### Dashboard
- System uptime and performance metrics
- Real-time request/error rate monitoring
- Quick access to key management functions

### KMS Management
- View active secp256k1 keys
- Monitor key usage and status
- Key rotation planning (future)

### Signature Monitoring
- Recent signature operations
- Performance analytics
- Built-in testing interface

### Security Features
- CORS-protected API endpoints
- Request rate monitoring
- Error tracking and alerting

## Configuration

Update `vite.config.ts` to change the backend proxy target:

```typescript
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8080', // Your sign-service URL
      changeOrigin: true,
      rewrite: (path) => path.replace(/^\/api/, '')
    }
  }
}
```

## Development

The UI auto-refreshes on code changes and includes:

- Hot module replacement
- TypeScript checking
- Tailwind CSS with JIT compilation
- Vue DevTools support

## Deployment

For production deployment:

1. Build the static assets: `npm run build`
2. Serve the `dist/` directory with any static file server
3. Configure reverse proxy to backend API
4. Set up proper CORS policies

## Security Considerations

- Enable HTTPS in production
- Configure proper CORS origins
- Implement authentication (future)
- Add rate limiting for admin endpoints
- Monitor for suspicious activity

## Contributing

1. Follow Vue 3 Composition API patterns
2. Use TypeScript for all new components
3. Maintain Tailwind CSS class organization
4. Test all admin functions end-to-end
