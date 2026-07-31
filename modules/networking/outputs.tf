output "vnet_id" {
  description = "ID of the created virtual network"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the created virtual network"
  value       = azurerm_virtual_network.this.name
}

output "compute_subnet_id" {
  description = "ID of the compute (App Service delegated) subnet"
  value       = azurerm_subnet.compute.id
}

output "database_subnet_id" {
  description = "ID of the database (Postgres Flexible Server delegated) subnet"
  value       = azurerm_subnet.database.id
}
