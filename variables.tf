variable "pm_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "ui_api_key" {
  description = "Unifi API Key (Network > Settings > Control Plane > Integrations)"
  type        = string
  sensitive   = true
}

variable "insecure" {
  description = "Whether to use an insecure tls connection"
  type        = bool
}

variable "cloudflare_token" {
  description = "Token with permissions to manage DNS records for the managed domain in cloudflare"
  type        = string
  sensitive   = true
}

variable "acme_email" {
  description = "Email for registering for an ACME account (Let's Encrypt)"
  type        = string
}

variable "base_public_domain" {
  description = "Domain for publicly exposing services (example.com)"
  type        = string
}

variable "keycloak_admin_password" {
  description = "Password for administrating Keycloak OIDC"
  type        = string
  sensitive   = true
}

variable "oauth2_proxy_client_secret" {
  description = "Client Secret for oauth2-proxy"
  type        = string
  sensitive   = true
}

variable "oauth2_proxy_cookie_secret" {
  description = "Cookie Secret for oauth2-proxy"
  type        = string
  sensitive   = true
}

variable "grafana_username" {
  description = "Grafana admin username"
  type        = string
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "entra_client_id" {
  description = "Microsoft Entra App Registration Client ID (Application ID)"
  type = string
}

variable "entra_client_secret" {
  description = "Microsoft Entra App Registration Client Secret"
  type = string
  sensitive = true
}

variable "entra_tenant_id" {
  description = "Microsoft Entra Tenant ID"
  type = string
}
