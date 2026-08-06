# modules/database/main.tf
#
# Deploys either a standalone/primary Postgres Flexible Server
# (create_mode = Default) or a cross-region read replica
# (create_mode = Replica), depending on how this module is invoked.
#
# Read replicas require General Purpose or Memory Optimized compute —
# Burstable is not supported (verified against Microsoft Learn docs,
# see ADR-0004). Authentication is Entra ID only — no admin password
# exists anywhere in this configuration.

# VNet-integrated Flexible Server requires a private DNS zone for name
# resolution within its own VNet. Each region needs its own zone.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.environment}.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "pdz-link-${var.environment}"
  resource_group_name  = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = "psql-haplatform-${var.environment}"
  resource_group_name = var.resource_group_name
  location             = var.location
  version              = var.postgres_version

  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  # Required when using VNet integration (delegated subnet + private DNS
  # zone) — Azure rejects the combination if public access isn't explicitly
  # disabled. The whole point of VNet integration is that the database is
  # never reachable from the public internet.
  public_network_access_enabled = false

  sku_name   = var.sku_name
  storage_mb = var.storage_mb

  # A replica's zone is determined by the platform automatically — forcing
  # a specific zone on Replica creation isn't a supported input and may
  # itself be a source of provisioning failures. Only set zone explicitly
  # for a standalone/primary server.
  zone = var.create_mode == "Default" ? var.zone : null

  create_mode      = var.create_mode
  source_server_id = var.create_mode == "Replica" ? var.source_server_id : null

  # Discovered via testing (3 identical InternalServerError failures on
  # replica creation) to be a real prerequisite for cross-region read
  # replicas, despite not being stated as a hard requirement in official
  # docs. Only settable at creation time — cannot be changed later. Only
  # applies to the primary; a replica cannot have its own geo-backup config.
  geo_redundant_backup_enabled = var.create_mode == "Default" ? var.geo_redundant_backup_enabled : false

  # High availability only applies to a standalone/primary server — a
  # replica cannot have its own HA standby.
  dynamic "high_availability" {
    for_each = (var.high_availability_enabled && var.create_mode == "Default") ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.standby_availability_zone
    }
  }

  # Entra ID only — no admin_password anywhere in this configuration.
  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = var.tenant_id
  }

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  lifecycle {
    # Azure may adjust the assigned zone during provisioning; don't fight it
    ignore_changes = [zone]
  }
}

# Assigns the signed-in user as database admin via Entra ID. Only created
# for the primary/standalone server — a replica inherits admin config
# from its source and cannot have its own separate assignment.
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "this" {
  count = var.create_mode == "Default" ? 1 : 0

  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id            = var.tenant_id
  object_id            = var.entra_admin_object_id
  principal_name        = var.entra_admin_principal_name
  principal_type        = "User"
}
