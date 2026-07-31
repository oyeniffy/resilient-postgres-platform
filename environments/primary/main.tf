# South Africa North (primary/active) — root configuration

locals {
  environment = "primary"
  location    = "southafricanorth"
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
  vnet_address_space       = ["10.0.0.0/16"]
  compute_subnet_prefix    = "10.0.1.0/24"
  database_subnet_prefix   = "10.0.2.0/24"
  tags                     = local.tags
}
