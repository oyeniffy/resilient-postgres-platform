variable "resource_group_name" {
  description = "Name of the resource group this network lives in"
  type        = string
}

variable "location" {
  description = "Azure region for this network (e.g. southafricanorth, southafricawest)"
  type        = string
}

variable "environment" {
  description = "Short environment label used in resource naming (e.g. primary, secondary)"
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR block for the VNet. Must not overlap with the paired region's VNet."
  type        = list(string)
}

variable "compute_subnet_prefix" {
  description = "CIDR block for the compute (App Service VNet integration) subnet"
  type        = string
}

variable "database_subnet_prefix" {
  description = "CIDR block for the database (Postgres Flexible Server delegated) subnet"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
}
