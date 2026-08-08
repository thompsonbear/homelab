variable "name" {
  type        = string
  description = "Name of the Azure Key Vault to reference"
  sensitive   = true
}

variable "resource_group" {
  type        = string
  description = "Resource Group containing the target Azure Key Vault"
  sensitive   = true
}
