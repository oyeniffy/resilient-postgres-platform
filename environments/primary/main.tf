# South Africa North (primary/active) — root configuration

data "azurerm_client_config" "current" {}

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

# ---- Entra ID admin identity ----
variable "entra_admin_object_id" {
  type        = string
  description = "Your Entra ID object ID — from 'az ad signed-in-user show'"
}

variable "entra_admin_principal_name" {
  type        = string
  description = "Your Entra ID UPN (usually your sign-in email) — from 'az ad signed-in-user show'"
}

module "database" {
  source = "../../modules/database"

  resource_group_name = azurerm_resource_group.this.name
  location             = local.location
  environment           = local.environment
  delegated_subnet_id   = module.networking.database_subnet_id
  vnet_id               = module.networking.vnet_id

  create_mode                   = "Default"
  high_availability_enabled     = true
  geo_redundant_backup_enabled  = true

  tenant_id                   = data.azurerm_client_config.current.tenant_id
  entra_admin_object_id       = var.entra_admin_object_id
  entra_admin_principal_name  = var.entra_admin_principal_name

  tags = local.tags
}

# ---- VNet peering to secondary ----
# Both database servers use public_network_access_enabled = false, meaning
# they are ONLY reachable over private networking. Cross-region read
# replica creation requires a network path between the two VNets — Azure
# does not create this automatically. Discovered via a real failure:
# "ReadReplicaToSourceServerNetworkBlocked" after 5 identical-looking but
# actually-network-caused replica creation failures. See ADR-0004 amendment.
#
# Peering is bidirectional: this resource is the primary -> secondary side.
# The matching secondary -> primary resource lives in environments/secondary.
data "terraform_remote_state" "secondary" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-haplatform"
    storage_account_name = "sthaplatformtfstate6430"
    container_name        = "tfstate"
    key                   = "secondary.tfstate"
  }
}

resource "azurerm_virtual_network_peering" "to_secondary" {
  name                      = "peer-primary-to-secondary"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = module.networking.vnet_name
  remote_virtual_network_id = data.terraform_remote_state.secondary.outputs.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic       = false
  allow_gateway_transit          = false
  use_remote_gateways             = false
}

output "postgres_server_id" {
  value = module.database.server_id
}

output "postgres_server_fqdn" {
  value = module.database.server_fqdn
}

output "vnet_id" {
  description = "Primary VNet ID, consumed by secondary environment to establish the reverse VNet peering"
  value       = module.networking.vnet_id
}

# ---- Compute (App Service) ----
module "compute" {
  source = "../../modules/compute"

  resource_group_name = azurerm_resource_group.this.name
  location             = local.location
  environment           = local.environment
  compute_subnet_id     = module.networking.compute_subnet_id

  app_settings = {
    REGION_NAME      = local.environment
    DB_HOST          = module.database.server_fqdn
    DB_NAME          = "postgres"
    WEBSITES_PORT    = "8080"
  }

  tags = local.tags
}

output "app_default_hostname" {
  value = module.compute.default_hostname
}

output "app_identity_principal_id" {
  description = "Grant this identity access inside Postgres manually via SQL — not automatable through Terraform"
  value       = module.compute.identity_principal_id
}
