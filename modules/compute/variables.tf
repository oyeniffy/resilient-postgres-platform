variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  description = "Short environment label (primary, secondary)"
  type        = string
}

variable "compute_subnet_id" {
  description = "ID of the subnet delegated to Microsoft.Web/serverFarms, for regional VNet integration"
  type        = string
}

variable "sku_name" {
  description = "App Service Plan SKU. Must be Basic or higher — regional VNet integration is not supported on Free/Shared tiers."
  type        = string
  default     = "B1"
}

variable "health_check_path" {
  description = "Path the platform (and later, Front Door/Traffic Manager) probes to determine instance health"
  type        = string
  default     = "/health"
}

variable "app_settings" {
  description = "Application settings (non-secret). Database connection uses Entra ID auth, so no password is ever passed here — only host/port/database name."
  type        = map(string)
  default     = {}
}

variable "tags" {
  type = map(string)
}
