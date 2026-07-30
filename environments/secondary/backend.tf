# Terraform remote state backend — South Africa West (secondary)
#
# Same storage account/container as primary; separate state KEY so the
# two environments' state files never collide or get applied together
# by accident.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-haplatform"
    storage_account_name = "sthaplatformtfstate6430"
    container_name        = "tfstate"
    key                   = "secondary.tfstate"
  }
}
