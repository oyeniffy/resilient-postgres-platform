# Terraform remote state backend — South Africa North (primary)
#
# Values below come from running scripts/bootstrap-backend.sh once.
# storage_account_name is globally unique and randomly suffixed by the
# bootstrap script — replace the placeholder with your actual value.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-haplatform"
    storage_account_name = "sthaplatformtfstate6430"
    container_name        = "tfstate"
    key                   = "primary.tfstate"
  }
}
