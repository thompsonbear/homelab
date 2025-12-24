resource "random_password" "grafana_client_secret" {
  length = 32
  # override_special = "!#$%&*()-_=+[]{}<>:?"
  special = false # Grafana seems to not like some special characters when they are specified through the configuration
}
