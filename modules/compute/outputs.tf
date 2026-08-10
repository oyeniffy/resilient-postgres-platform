output "default_hostname" {
  value = azurerm_linux_web_app.this.default_hostname
}

output "identity_principal_id" {
  description = "The App Service's managed identity object ID — needed to grant this identity access inside Postgres (a SQL-level GRANT, done manually, not by Terraform)"
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}

output "app_name" {
  value = azurerm_linux_web_app.this.name
}
