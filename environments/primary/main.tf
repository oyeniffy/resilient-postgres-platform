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
# Object ID and UPN of the human user this project's database admin
# access is assigned to. These are NOT auto-discoverable by Terraform
# (there's no API for "who is the human currently running az login") —
# fetch them once via:
#   az ad signed-in-user show --query "{objectId:id, upn:userPrincipalName}" -o table
# and pass them at apply time (see README/commands for the exact flags),
# rather than hardcoding here.
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

  create_mode                = "Default"
  high_availability_enabled  = true

  tenant_id                   = data.azurerm_client_config.current.tenant_id
  entra_admin_object_id       = var.entra_admin_object_id
  entra_admin_principal_name  = var.entra_admin_principal_name

  tags = local.tags
}

output "postgres_server_id" {
  value = module.database.server_id
}

output "postgres_server_fqdn" {
  value = module.database.server_fqdn
}
