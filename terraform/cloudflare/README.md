# Cloudflare DNS Management

Terraform module for managing Cloudflare DNS records and security settings for Mineclifford.

## Prerequisites

1. **Cloudflare account** with domain `mineclifford.com` added
2. **API Token** with permissions:
   - Zone:DNS:Edit
   - Zone:Zone:Read
   - Zone:Zone Settings:Edit (for security rules)

## Usage

### 1. Create API Token

<https://dash.cloudflare.com/profile/api-tokens>

- Template: **Edit zone DNS**
- Permissions:
  - Zone → DNS → Edit
  - Zone → Zone Settings → Edit
  - Zone → Zone → Read
- Zone Resources: `mineclifford.com`

### 2. Initialize and Apply

```bash
cd terraform/cloudflare

# Initialize
terraform init

# Plan (check what will be created)
terraform plan \
  -var="cloudflare_api_token=YOUR_TOKEN_HERE" \
  -var="platform_ip=YOUR_SERVER_IP"

# Apply (create DNS records)
terraform apply \
  -var="cloudflare_api_token=YOUR_TOKEN_HERE" \
  -var="platform_ip=YOUR_SERVER_IP"
```

### 3. Use Environment Variables (Recommended)

```bash
# Set variables
export TF_VAR_cloudflare_api_token="your_token"
export TF_VAR_platform_ip="1.2.3.4"

# Then just run
terraform apply
```

### 4. With terraform.tfvars (Most Secure)

```bash
# Create terraform.tfvars (gitignored)
cat > terraform.tfvars <<EOF
cloudflare_api_token = "your_token_here"
platform_ip          = "1.2.3.4"
user_servers_lb_ip   = "5.6.7.8"  # Optional
EOF

# Apply
terraform apply
```

## Created Resources

### DNS Records

| Record | Type | Value | Proxied | Purpose |
|--------|------|-------|---------|---------|
| `@` | A | `platform_ip` | ✅ Yes | Main dashboard |
| `api` | A | `platform_ip` | ✅ Yes | API endpoint |
| `traefik` | A | `platform_ip` | ✅ Yes | Traefik UI |
| `*.servers` | A | `user_servers_lb_ip` | ❌ No | Game servers |

### Security Settings

- ✅ **SSL**: Strict (Full encryption)
- ✅ **HTTPS Redirect**: Always use HTTPS
- ✅ **HSTS**: Enabled with 1-year max-age
- ✅ **TLS 1.3**: Enabled
- ✅ **Bot Fight Mode**: Block malicious bots
- ✅ **Challenge Score**: Challenge suspicious requests
- ✅ **Browser Integrity**: Check browser signatures

### Performance Settings

- ✅ **Brotli**: Enabled
- ✅ **HTTP/2**: Enabled
- ✅ **HTTP/3**: Enabled
- ✅ **Minification**: CSS, JS, HTML
- ✅ **Caching**: Aggressive mode

## Outputs

```bash
terraform output
```

```
dns_records = {
  api              = "api.mineclifford.com"
  root_domain      = "mineclifford.com"
  servers_wildcard = "*.servers.mineclifford.com"
  traefik          = "traefik.mineclifford.com"
}
nameservers = [
  "brianna.ns.cloudflare.com",
  "dion.ns.cloudflare.com"
]
zone_id = "abc123..."
```

## Integration with Platform Deployment

After applying this module, your DNS will be configured and you can deploy the platform:

```bash
# Deploy platform with Traefik
cd ../..
docker compose -f docker-compose.traefik.yml up -d
```

Traefik will automatically request Let's Encrypt certificates via Cloudflare DNS challenge.

## Cleanup

```bash
# Destroy all DNS records
terraform destroy
```

⚠️ **Warning**: This will remove ALL DNS records managed by this module!

## Troubleshooting

### "Zone not found"

Make sure `mineclifford.com` is added to your Cloudflare account.

### "API token insufficient permissions"

Recreate token with required permissions (see Prerequisites).

### "Rate limit exceeded"

Wait a few minutes and try again. Cloudflare has API rate limits.

## Advanced: State Backend

For production, use remote state:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "mineclifford-terraform-state"
    key    = "cloudflare/terraform.tfstate"
    region = "us-east-2"
  }
}
```

Or use Terraform Cloud:

```hcl
terraform {
  cloud {
    organization = "mineclifford"
    workspaces {
      name = "dns-management"
    }
  }
}
```
