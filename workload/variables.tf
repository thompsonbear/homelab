variable "az_key_vault_name" {
  type        = string
  description = "Name of the Azure Key Vault to reference for secret values"
  sensitive   = true
}

variable "az_key_vault_rg" {
  type        = string
  description = "Resource Group containing the target Azure Key Vault"
  sensitive   = true
}

variable "environment" {
  type        = string
  description = "The environment type (prod/staging/dev/etc.)"
}
