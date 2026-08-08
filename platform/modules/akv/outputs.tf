output "secrets" {
  value = local.secrets
}

output "id" {
  value = data.azurerm_key_vault.akv.id
}
