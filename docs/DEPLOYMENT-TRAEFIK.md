# Deploying Mineclifford with Traefik (Alpha Testing)

This guide explains how to deploy Mineclifford with Traefik reverse proxy, Let's Encrypt SSL certificates via Cloudflare DNS challenge, and BasicAuth protection for alpha testing.

## Prerequisites

1. **Domain managed by Cloudflare**: `mineclifford.com`
2. **Server with Docker & Docker Compose** installed
3. **Cloudflare API Token** with DNS edit permissions
4. **AWS/Azure credentials** (for cloud deployments)

---

## Quick Start

### 1. Generate BasicAuth Password

```bash
# Generate password hash for Traefik BasicAuth
./scripts/generate-basicauth.sh admin YourSecurePassword123

# Copy the output to your .env file
```

### 2. Configure Environment Variables

```bash
# Copy example and edit
cp .env.example .env
nano .env
```

**Required variables:**

```env
# Domain
DOMAIN_NAME=mineclifford.com
ACME_EMAIL=admin@mineclifford.com

# Cloudflare
CF_API_EMAIL=your_email@example.com
CF_API_TOKEN=your_cloudflare_api_token_here

# BasicAuth (from step 1)
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD_HASH=admin:$$2y$$05$$...

# Timezone
TZ=America/Sao_Paulo
```

### 3. Start Services

```bash
# Start Traefik + Web Platform
docker compose -f docker-compose.traefik.yml up -d

# Check logs
docker compose -f docker-compose.traefik.yml logs -f
```

### 4. Access Platform

After DNS propagation (~2 minutes):

- **Dashboard**: <https://mineclifford.com> (BasicAuth required)
- **API**: <https://api.mineclifford.com/docs>
- **Traefik Dashboard**: <https://traefik.mineclifford.com> (BasicAuth required)

**Default credentials**: The username/password you set in step 1

---

## Security Features (Alpha Version)

### BasicAuth Protection

All routes are protected with HTTP BasicAuth:
- ✅ Dashboard: `https://mineclifford.com`
- ✅ API: `https://api.mineclifford.com`
- ✅ Traefik UI: `https://traefik.mineclifford.com`

**Important**: This is temporary for alpha testing. Remove `alpha-auth` middleware labels when implementing proper user authentication.

### SSL/TLS

- ✅ Automatic Let's Encrypt certificates via Cloudflare DNS challenge
- ✅ Wildcard certificate for `*.mineclifford.com`
- ✅ HTTPS redirect (HTTP → HTTPS)
- ✅ HSTS headers with 1 year max-age

### Security Headers

Applied to all responses:
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`

### Docker Socket Protection

- ✅ Read-only mount: `/var/run/docker.sock:/var/run/docker.sock:ro`
- ⚠️ **Still risky** - consider using [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)

---

## Cloudflare Setup

### 1. Create API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use template: **Edit zone DNS**
4. Configure:
   - **Permissions**:
     - Zone → DNS → Edit
     - Zone → Zone → Read
   - **Zone Resources**:
     - Include → Specific zone → `mineclifford.com`
5. Create and save the token

### 2. DNS Records (Auto-created by Terraform)

The platform will create these records:
```
A     @              → <server-ip>
A     api            → <server-ip>
A     traefik        → <server-ip>
A     *.servers      → <load-balancer-ip>  # For user Minecraft servers
```

Cloudflare proxy status:
- `mineclifford.com` → ☁️ Proxied (DDoS protection)
- `api.mineclifford.com` → ☁️ Proxied
- `*.servers.mineclifford.com` → 🌐 DNS only (direct to game servers)

---

## Directory Structure

```
mineclifford/
├── docker-compose.traefik.yml     # Production deployment config
├── docker/
│   ├── traefik/
│   │   └── dynamic/               # Dynamic Traefik config (optional)
│   └── web/
│       ├── Dockerfile
│       ├── nginx-traefik.conf     # Nginx config for Traefik
│       └── nginx.conf             # Nginx config for local dev
├── scripts/
│   └── generate-basicauth.sh      # Password hash generator
└── .env                           # Your actual secrets (gitignored)
```

---

## Troubleshooting

### Certificate Issues

```bash
# Check Traefik logs
docker logs mineclifford-traefik

# Common issues:
# 1. Cloudflare API token invalid
# 2. DNS not propagated yet (wait 2-5 min)
# 3. Rate limit (use staging ACME server for testing)
```

Enable staging server in `docker-compose.traefik.yml`:
```yaml
- "--certificatesresolvers.cloudflare.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
```

### BasicAuth Not Working

```bash
# Regenerate hash
./scripts/generate-basicauth.sh admin newpassword

# Important: Password hash must be double-escaped in .env
# Correct:   TRAEFIK_DASHBOARD_PASSWORD_HASH=admin:$$2y$$05$$...
# Wrong:     TRAEFIK_DASHBOARD_PASSWORD_HASH=admin:$2y$05$...
```

### Cannot Access Dashboard

1. Check DNS:
   ```bash
   dig mineclifford.com
   dig api.mineclifford.com
   ```

2. Check Traefik routing:
   ```bash
   docker exec mineclifford-traefik wget -qO- http://localhost:8080/api/http/routers
   ```

3. Check container health:
   ```bash
   docker compose -f docker-compose.traefik.yml ps
   ```

---

## Migration Path

### Phase 1: Alpha (Current)
- ✅ BasicAuth on all routes
- ✅ Manual credential sharing with testers
- ✅ Single admin account

### Phase 2: Beta
- 🔄 Implement user registration/login
- 🔄 JWT-based API authentication
- 🔄 Remove BasicAuth middleware
- 🔄 Add rate limiting per user

### Phase 3: Production
- 🔄 OAuth2 providers (Google, GitHub)
- 🔄 Multi-tenant database
- 🔄 Billing integration
- 🔄 Auto-scaling

---

## Removing BasicAuth (When Ready)

When you implement proper user authentication:

1. **Remove BasicAuth labels** from `docker-compose.traefik.yml`:
   ```yaml
   # DELETE these lines:
   - "traefik.http.routers.api.middlewares=alpha-auth,security-headers"
   - "traefik.http.middlewares.alpha-auth.basicauth.users=..."
   ```

2. **Keep security headers**:
   ```yaml
   # KEEP this:
   - "traefik.http.routers.api.middlewares=security-headers"
   ```

3. **Restart Traefik**:
   ```bash
   docker compose -f docker-compose.traefik.yml restart traefik
   ```

---

## Next Steps

1. ✅ Deploy with Traefik
2. ⏭️ Test cloud deployment (AWS/Azure)
3. ⏭️ Implement user authentication
4. ⏭️ Add frontend UI for cloud deployments
5. ⏭️ Setup monitoring (Prometheus/Grafana)
6. ⏭️ Create billing system (Stripe)

---

## Support

For issues or questions:
- Create an issue on GitHub
- Check logs: `docker compose -f docker-compose.traefik.yml logs`
- Review Traefik docs: https://doc.traefik.io/traefik/
