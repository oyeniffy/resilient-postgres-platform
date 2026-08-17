# modules/frontdoor/main.tf
#
# Azure Front Door (Standard tier — cheapest tier that supports priority-
# based origin failover, which is the actual mechanism this project needs).
#
# Priority-based routing: primary origin has priority 1, secondary has
# priority 2. Front Door sends all traffic to the lowest-priority origin
# that's passing health probes. If primary fails its health probe
# (hitting /health, same endpoint the App Service itself uses), Front
# Door automatically shifts all traffic to secondary — this is the actual
# failover mechanism the whole project exists to demonstrate and test.

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "fd-haplatform"
  resource_group_name = var.resource_group_name
  sku_name             = "Standard_AzureFrontDoor"
  tags                 = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "haplatform"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = "og-haplatform"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  health_probe {
    path                = var.health_check_path
    protocol             = "Https"
    request_type          = "GET"
    interval_in_seconds    = 30
  }

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }
}

resource "azurerm_cdn_frontdoor_origin" "primary" {
  name                          = "origin-primary"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id

  enabled                        = true
  host_name                       = var.primary_origin_hostname
  origin_host_header               = var.primary_origin_hostname
  http_port                        = 80
  https_port                       = 443
  priority                         = 1
  weight                           = 1000
  certificate_name_check_enabled   = true
}

resource "azurerm_cdn_frontdoor_origin" "secondary" {
  name                          = "origin-secondary"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id

  enabled                        = true
  host_name                       = var.secondary_origin_hostname
  origin_host_header               = var.secondary_origin_hostname
  http_port                        = 80
  https_port                       = 443
  priority                         = 2
  weight                           = 1000
  certificate_name_check_enabled   = true
}

resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = "route-haplatform"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids      = [
    azurerm_cdn_frontdoor_origin.primary.id,
    azurerm_cdn_frontdoor_origin.secondary.id,
  ]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match        = ["/*"]
  forwarding_protocol       = "HttpsOnly"
  https_redirect_enabled     = true
  link_to_default_domain      = true
}
