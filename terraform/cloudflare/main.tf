terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Get zone information
data "cloudflare_zone" "main" {
  name = var.domain_name
}

# Main domain (platform)
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  value   = var.platform_ip
  type    = "A"
  ttl     = 1  # Automatic (proxied)
  proxied = true  # Enable Cloudflare proxy (DDoS protection, CDN)
  comment = "Mineclifford platform - root domain"
}

# API subdomain
resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.main.id
  name    = "api"
  value   = var.platform_ip
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "Mineclifford API endpoint"
}

# Traefik dashboard
resource "cloudflare_record" "traefik" {
  zone_id = data.cloudflare_zone.main.id
  name    = "traefik"
  value   = var.platform_ip
  type    = "A"
  ttl     = 1
  proxied = true
  comment = "Traefik dashboard"
}

# Wildcard for user Minecraft servers (NOT proxied - direct TCP)
resource "cloudflare_record" "servers_wildcard" {
  count   = var.user_servers_lb_ip != "" ? 1 : 0
  zone_id = data.cloudflare_zone.main.id
  name    = "*.servers"
  value   = var.user_servers_lb_ip
  type    = "A"
  ttl     = 300
  proxied = false  # Direct connection for game servers (TCP/UDP)
  comment = "Wildcard for user-provisioned Minecraft servers"
}

# Zone settings
resource "cloudflare_zone_settings_override" "main" {
  zone_id = data.cloudflare_zone.main.id

  settings {
    # SSL/TLS
    ssl                      = "strict"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"

    # Security
    security_level           = "high"
    challenge_ttl            = 1800
    browser_check            = "on"
    privacy_pass             = "on"
    security_header {
      enabled            = true
      max_age            = 31536000
      include_subdomains = true
      preload            = true
      nosniff            = true
    }

    # Performance
    brotli               = "on"
    early_hints          = "on"
    http2                = "on"
    http3                = "on"
    min_tls_version      = "1.2"
    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }

    # Caching
    browser_cache_ttl = 14400
    cache_level       = "aggressive"

    # Development mode (disable for production)
    development_mode = "off"
  }
}

# Firewall rule: Block common attack patterns
resource "cloudflare_ruleset" "zone_firewall" {
  zone_id     = data.cloudflare_zone.main.id
  name        = "Mineclifford Security Rules"
  description = "Security rules for Mineclifford platform"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "block"
    description = "Block known bad bots"
    enabled     = true
    expression  = "(cf.client.bot) and not (cf.verified_bot_category in {\"Search Engine Crawler\" \"Page Preview\" \"Monitoring & Analytics\"})"
  }

  rules {
    action      = "challenge"
    description = "Challenge suspicious requests"
    enabled     = true
    expression  = "(cf.threat_score > 10)"
  }
}

# Rate limiting (requires Cloudflare Business plan or higher)
# Uncomment if you have Business+ plan
# resource "cloudflare_rate_limit" "api" {
#   zone_id   = data.cloudflare_zone.main.id
#   threshold = 100
#   period    = 60
#   match {
#     request {
#       url_pattern = "${var.domain_name}/api/*"
#     }
#   }
#   action {
#     mode    = "challenge"
#     timeout = 86400
#   }
#   description = "Rate limit API requests to 100/min"
# }
