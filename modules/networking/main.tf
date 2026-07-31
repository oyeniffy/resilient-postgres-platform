# modules/networking/main.tf
#
# Creates an isolated network boundary for one region: a VNet with two
# subnets (compute, database), each with an explicit-allow-only NSG.
# No default-allow-all rules — every permitted flow is intentional and
# documented below.

resource "azurerm_virtual_network" "this" {
  name                = "vnet-haplatform-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# --- Compute subnet ---
# Delegated to Microsoft.Web/serverFarms so App Service can VNet-integrate
# for outbound traffic to the database subnet without going over the
# public internet.
resource "azurerm_subnet" "compute" {
  name                 = "snet-compute-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.compute_subnet_prefix]

  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# --- Database subnet ---
# Delegated to Microsoft.DBforPostgreSQL/flexibleServers, required for
# Postgres Flexible Server's VNet-integrated (private access) networking
# mode. Keeps the database off the public internet entirely.
resource "azurerm_subnet" "database" {
  name                 = "snet-database-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.database_subnet_prefix]

  delegation {
    name = "postgres-flexible-server-delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# --- NSG: compute subnet ---
# Allows only inbound HTTPS (for App Service platform traffic) and
# outbound to the database subnet on the Postgres port. Everything else
# is implicitly denied by Azure's default deny-all lowest-priority rule.
resource "azurerm_network_security_group" "compute" {
  name                = "nsg-compute-${var.environment}"
  resource_group_name = var.resource_group_name
  location             = var.location
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    description                = "Allow inbound HTTPS from the internet, terminated at App Service"
  }

  security_rule {
    name                       = "AllowPostgresOutboundToDatabaseSubnet"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.compute_subnet_prefix
    destination_address_prefix = var.database_subnet_prefix
    description                = "Allow the app to reach Postgres Flexible Server on its subnet"
  }
}

resource "azurerm_subnet_network_security_group_association" "compute" {
  subnet_id                 = azurerm_subnet.compute.id
  network_security_group_id = azurerm_network_security_group.compute.id
}

# --- NSG: database subnet ---
# Allows only inbound Postgres traffic from the compute subnet. No
# internet-facing rule of any kind — the database is never directly
# reachable from outside this VNet.
resource "azurerm_network_security_group" "database" {
  name                = "nsg-database-${var.environment}"
  resource_group_name = var.resource_group_name
  location             = var.location
  tags                = var.tags

  security_rule {
    name                       = "AllowPostgresInboundFromComputeSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.compute_subnet_prefix
    destination_address_prefix = var.database_subnet_prefix
    description                = "Allow only the app subnet to reach Postgres — no other inbound source permitted"
  }
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}
