resource "random_password" "immich_client_secret" {
  length = 32
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
