output "server_id" {
  description = "Resource ID of the Postgres Flexible Server (used by the secondary environment to create a replica)"
  value       = azurerm_postgresql_flexible_server.this.id
}

output "server_name" {
  value = azurerm_postgresql_flexible_server.this.name
}

output "server_fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}
