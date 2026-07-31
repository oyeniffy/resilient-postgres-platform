terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
  }
}

provider "azurerm" {
  features {}

  # By default the azurerm provider tries to auto-register ~40 resource
  # providers on first run, including many this project never touches
  # (Databricks, Service Fabric, Bot Service, etc). On a policy-governed
  # subscription this can fail on providers we don't have permission for,
  # or just time out. "core" restricts registration to providers actually
  # required by resources declared in this configuration.
  resource_provider_registrations = "core"
}
