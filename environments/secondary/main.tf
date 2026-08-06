# West Europe (secondary/passive) — root configuration
#
# Originally scoped as South Africa West; changed after deployment hit a
# subscription-level allowed-locations policy. See ADR-0001 amendment.

data "azurerm_client_config" "current" {}

locals {
  environment = "secondary"
  location    = "westeurope"
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

# Reads primary's state as a data source ONLY — this environment cannot
# modify primary's resources, just read its outputs (the server ID needed
# to create the replica). See ADR-0004 for why this cross-state reference
# is used instead of merging into a single shared state.
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

output "postgres_replica_id" {
  value = module.database.server_id
}

output "postgres_replica_fqdn" {
  value = module.database.server_fqdn
}
