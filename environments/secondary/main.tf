# North Europe (secondary/passive) — root configuration
#
# Originally South Africa West (subscription policy block), then West
# Europe (cross-region replica creation failed 4x with generic Azure
# platform errors, later diagnosed as a missing VNet peering issue — see
# ADR-0001 and ADR-0004 amendments for full history).

data "azurerm_client_config" "current" {}

locals {
  environment = "secondary"
  location    = "northeurope"
  tags = {
    Owner       = "nifemi"
    CostCenter  = "personal-portfolio"
    Project     = "resilient-postgres-platform"
    Environment = local.environment
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-haplatform-${local.environment}"
  location = local.location
  tags     = local.tags
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name    = azurerm_resource_group.this.name
  location                = local.location
  environment              = local.environment
  vnet_address_space       = ["10.1.0.0/16"]
  compute_subnet_prefix    = "10.1.1.0/24"
  database_subnet_prefix   = "10.1.2.0/24"
  tags                     = local.tags
}

data "terraform_remote_state" "primary" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-haplatform"
    storage_account_name = "sthaplatformtfstate6430"
    container_name        = "tfstate"
    key                   = "primary.tfstate"
  }
}

module "database" {
  source = "../../modules/database"

  resource_group_name = azurerm_resource_group.this.name
  location             = local.location
  environment           = local.environment
  delegated_subnet_id   = module.networking.database_subnet_id
  vnet_id               = module.networking.vnet_id

  create_mode       = "Replica"
  source_server_id  = data.terraform_remote_state.primary.outputs.postgres_server_id

  tenant_id = data.azurerm_client_config.current.tenant_id

  tags = local.tags
}

# ---- VNet peering to primary (reverse side) ----
# See environments/primary/main.tf for the full explanation. This is the
# secondary -> primary half of the bidirectional peering. Both halves must
# exist for traffic to flow in both directions.
resource "azurerm_virtual_network_peering" "to_primary" {
  name                      = "peer-secondary-to-primary"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = module.networking.vnet_name
  remote_virtual_network_id = data.terraform_remote_state.primary.outputs.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic       = false
  allow_gateway_transit          = false
  use_remote_gateways             = false
}

output "postgres_replica_id" {
  value = module.database.server_id
}

output "postgres_replica_fqdn" {
  value = module.database.server_fqdn
}

output "vnet_id" {
  description = "Secondary VNet ID, consumed by primary environment to establish VNet peering"
  value       = module.networking.vnet_id
}
