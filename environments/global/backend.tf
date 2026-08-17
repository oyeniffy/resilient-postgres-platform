# Terraform remote state backend — global (cross-region resources)
#
# Same storage account/container as primary and secondary; separate state
# key so this environment's state never collides with either region's.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-haplatform"
    storage_account_name = "sthaplatformtfstate6430"
    container_name        = "tfstate"
    key                   = "global.tfstate"
  }
}
