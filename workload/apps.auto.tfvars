  app_defaults = {
    keycloak = {
      client_roles = ["admin"]
    }
    postgres = {
      version  = 18
      base_gb  = 20
      wal_gb   = 10
      encoding = "UTF8"
      sql      = []
      extensions = []
      instances = 2
    }
    valkey = {
      clustered = false
      shards    = 0
      instances = 3
      size_gb   = 10
    }
  }

  apps = {
    home-assistant = {
      namespace = "home-assistant"
      image_tag = "2025.12.4"
      chart = {
        name    = "home-assistant"
        repo    = "https://pajikos.github.io/home-assistant-helm-chart/"
        version = "0.3.36"
      }
      route = {
        labels         = ["home"]
        https_redirect = true
        public         = true
        svc_name       = "home-assistant"
        svc_port       = 8080
      }
    }
    # bluesky-pds = {
    #   namespace = "bluesky-pds"
    #   image_tag = "0.4.208"
    #   chart = {
    #     name    = "bluesky-pds"
    #     repo    = "https://charts.bear.fyi"
    #     version = "0.4.208"
    #   }
    #   dns = {
    #     labels = ["pds"]
    #     public = true
    #   }
    #   backend = {
    #     service = "bluesky-pds"
    #     port    = 3000
    #   }
    # }
    # immich = {
    #   namespace = "immich"
    #   chart = {
    #     name    = "immich"
    #     repo    = "https://charts.bear.fyi"
    #     version = "0.1.1"
    #   }
    #   dns = {
    #     labels = ["img", "immich"]
    #     public = true
    #   }
    #   backend = {
    #     service = "immich-api"
    #     port    = 2283
    #   }
    #   postgres = {
    #     base_gb  = 20
    #     wal_gb   = 10
    #     replicas = 1
    #     extensions = [{
    #       name    = "vchord"
    #       preload = true
    #       create  = true
    #       }, {
    #       name    = "pgvector"
    #       preload = false
    #       create  = false
    #     }]
    #   }
    #   valkey = {
    #     instances = 3
    #   }
    # }
  }
