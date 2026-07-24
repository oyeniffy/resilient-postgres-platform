# Terraform remote state backend — South Africa West (secondary)
#
# Same storage account/container as primary; separate state KEY so the
# two environments' state files never collide or get applied together
# by accident.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-haplatform"
    storage_account_name = "REPLACE_WITH_YOUR_STORAGE_ACCOUNT_NAME"
    container_name        = "tfstate"
    key                   = "secondary.tfstate"
  }
}
