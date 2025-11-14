output "zone_id" {
  description = "Cloudflare Zone ID"
  value       = data.cloudflare_zone.main.id
}

output "zone_name" {
  description = "Cloudflare Zone Name"
  value       = data.cloudflare_zone.main.name
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    root_domain = cloudflare_record.root.hostname
    api         = cloudflare_record.api.hostname
    traefik     = cloudflare_record.traefik.hostname
    servers_wildcard = var.user_servers_lb_ip != "" ? cloudflare_record.servers_wildcard[0].hostname : "not created"
  }
}

output "nameservers" {
  description = "Cloudflare nameservers for the zone"
  value       = data.cloudflare_zone.main.name_servers
}
