variable "resource_group_name" {
  type = string
}

variable "location" {
  description = "Location for the resource group. Front Door itself is a global service — this only affects where the RG metadata lives."
  type        = string
}

variable "primary_origin_hostname" {
  description = "Default hostname of the primary region's App Service"
  type        = string
}

variable "secondary_origin_hostname" {
  description = "Default hostname of the secondary region's App Service"
  type        = string
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "tags" {
  type = map(string)
}
