apps = {
  home-assistant = {
    namespace = "home-assistant"
    version   = "2025.12.4"
    chart = {
      name    = "home-assistant"
      repo    = "https://pajikos.github.io/home-assistant-helm-chart/"
      version = "0.3.36"
    }
    dns = {
      labels = ["home", "home-assistant"]
      public = true
    }
    backend = {
      service = "home-assistant"
      port    = 8080
    }
    # keycloak = {
    #   redirect_uris = [""]
    #   logout_uris = [""]
    #   client_roles = [""]
    # }
    # postgres = {
    #   base_gb = 10
    #   wal_gb = 2
    #   replicas = 1
    # }
    # valkey = {
    #   size_gb = 2
    #   replicas = 1
    # }
  }
}
