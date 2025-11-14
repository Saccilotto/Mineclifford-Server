variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit and Zone:Zone:Read permissions"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Main domain name managed by Cloudflare"
  type        = string
  default     = "mineclifford.com"
}

variable "platform_ip" {
  description = "IP address of the platform server (Traefik + Web Dashboard)"
  type        = string
}

variable "user_servers_lb_ip" {
  description = "IP address of load balancer for user Minecraft servers (optional)"
  type        = string
  default     = ""
}
