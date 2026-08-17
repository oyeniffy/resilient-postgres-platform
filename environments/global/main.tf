# Global — cross-region resources that don't belong to either environment
#
# Front Door lives here rather than in primary or secondary because it's
# not "in" either region — it's the traffic layer that sits above both.
# Kept in its own state file (global.tfstate) so it can be planned/applied
# independently of either region's infrastructure.

locals {
  tags = {
    Owner       = "nifemi"
    CostCenter  = "personal-portfolio"
    Project     = "resilient-postgres-platform"
    Environment = "global"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-haplatform-global"
  location = "southafricanorth"
  tags     = local.tags
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

data "terraform_remote_state" "secondary" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate-haplatform"
    storage_account_name = "sthaplatformtfstate6430"
    container_name        = "tfstate"
    key                   = "secondary.tfstate"
  }
}

module "frontdoor" {
  source = "../../modules/frontdoor"

  resource_group_name = azurerm_resource_group.this.name
  location             = "southafricanorth"

  primary_origin_hostname   = data.terraform_remote_state.primary.outputs.app_default_hostname
  secondary_origin_hostname = data.terraform_remote_state.secondary.outputs.app_default_hostname

  tags = local.tags
}

output "front_door_url" {
  description = "The single public entry point for the platform — use this, not either region's App Service hostname directly"
  value       = "https://${module.frontdoor.endpoint_hostname}"
}
