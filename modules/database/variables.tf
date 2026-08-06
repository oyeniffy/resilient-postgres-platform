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

variable "delegated_subnet_id" {
  description = "ID of the subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers"
  type        = string
}

variable "vnet_id" {
  description = "ID of the VNet this server's private DNS zone links to"
  type        = string
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "sku_name" {
  description = "Compute SKU, e.g. GP_Standard_D4ds_v5. Must be General Purpose or Memory Optimized — Burstable does not support read replicas."
  type        = string
  default     = "GP_Standard_D4ds_v5"
}

variable "storage_mb" {
  type    = number
  default = 32768 # 32 GiB, minimum for General Purpose
}

variable "zone" {
  description = "Primary availability zone for this server"
  type        = string
  default     = "1"
}

variable "high_availability_enabled" {
  description = "Enable zone-redundant HA. Only applies when create_mode = Default (replicas cannot have their own HA config)."
  type        = bool
  default     = false
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backup storage. Discovered via testing to be a real prerequisite for cross-region read replica creation, despite not being documented as a hard requirement — Azure returns a generic InternalServerError on replica creation if the source lacks this. Can only be set at server creation time; cannot be changed afterward. Only meaningful when create_mode = Default."
  type        = bool
  default     = false
}

variable "standby_availability_zone" {
  type    = string
  default = "2"
}

variable "create_mode" {
  description = "Default for a standalone/primary server, Replica for a cross-region read replica"
  type        = string
  default     = "Default"

  validation {
    condition     = contains(["Default", "Replica"], var.create_mode)
    error_message = "create_mode must be 'Default' or 'Replica'."
  }
}

variable "source_server_id" {
  description = "Required when create_mode = Replica: the resource ID of the primary server to replicate from"
  type        = string
  default     = null
}

variable "tenant_id" {
  description = "Azure AD tenant ID, used for Entra ID authentication"
  type        = string
}

variable "entra_admin_object_id" {
  description = "Object ID of the Entra ID user/group to assign as database admin. Only used when create_mode = Default."
  type        = string
  default     = null
}

variable "entra_admin_principal_name" {
  description = "UPN of the Entra ID admin user. Only used when create_mode = Default."
  type        = string
  default     = null
}

variable "tags" {
  type = map(string)
}
