output "endpoint_hostname" {
  description = "The public Front Door URL — this is the single entry point clients should use, not either region's App Service hostname directly"
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
}

output "profile_id" {
  value = azurerm_cdn_frontdoor_profile.this.id
}
