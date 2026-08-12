data "azurerm_key_vault" "akv" {
  name                = var.name
  resource_group_name = var.resource_group
}

data "azurerm_key_vault_secrets" "akv_secrets" {
  key_vault_id = data.azurerm_key_vault.akv.id
}

data "azurerm_key_vault_secret" "akv_secret_values" {
  for_each     = toset(data.azurerm_key_vault_secrets.akv_secrets.names)
  name         = each.key
  key_vault_id = data.azurerm_key_vault.akv.id
}

locals {
  secrets_raw = data.azurerm_key_vault_secret.akv_secret_values

  secrets_decoded = {
    for key, secret in local.secrets_raw : key => {
      json = try(jsondecode(secret.value), null)
      yaml = try(yamldecode(secret.value), null)
      csv  = try(csvdecode(secret.value), null)
    }
  }

  secrets = {
    for key, value in local.secrets_decoded : key =>
    value.json != null ? value.json :
    value.yaml != null ? value.yaml :
    value.csv != null ? value.csv :
    local.secrets_raw[key].value
  }
}




