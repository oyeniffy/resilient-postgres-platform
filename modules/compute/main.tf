# modules/compute/main.tf
#
# Linux App Service, per ADR-0003 (chosen over Container Apps/VMSS so that
# failures during the eventual failure drill point to the database/
# replication story, not compute-platform noise).
#
# Two things worth noting up front:
# - Regional VNet integration (outbound only) requires Basic tier or
#   higher — Free/Shared tiers don't support it.
# - The app authenticates to Postgres via its own system-assigned managed
#   identity (Entra ID auth only, per ADR-0004 — there is no password to
#   configure here). The identity still needs to be granted access inside
#   Postgres itself (a SQL-level GRANT, not a Terraform resource) — see
#   the module's outputs for the principal ID needed to do that.

resource "azurerm_service_plan" "this" {
  name                = "asp-haplatform-${var.environment}"
  resource_group_name = var.resource_group_name
  location             = var.location
  os_type               = "Linux"
  sku_name              = var.sku_name
  tags                  = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = "app-haplatform-${var.environment}"
  resource_group_name = var.resource_group_name
  location             = var.location
  service_plan_id      = azurerm_service_plan.this.id

  virtual_network_subnet_id = var.compute_subnet_id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    health_check_path                     = var.health_check_path
    health_check_eviction_time_in_min      = 2
    always_on                              = true
    minimum_tls_version                     = "1.2"
    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = var.app_settings

  tags = var.tags
}
