system = {
  cert_manager_tag = "1.21.1"
  metallb_tag      = "0.16.1"
  istio_tag        = "1.30.3"
  mayastor_tag     = "2.11.1"
  keycloak_tag     = "26.7.2"
  cnpg = {
    image_tag = "1.30.0"
    chart_tag = "0.29.0"
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
    dns = {
      labels = ["home", "home-assistant"]
      public = true
    }
    backend = {
      service = "home-assistant"
      port    = 8080
    }
  }
  #  bluesky-pds = {
  #    namespace     = "bluesky-pds"
  #    image_version = "0.4.208"
  #    chart = {
  #      name    = "bluesky-pds"
  #      repo    = "https://charts.bear.fyi"
  #      version = "0.4.208"
  #    }
  #    dns = {
  #      labels = ["pds"]
  #      public = true
  #    }
  #    backend = {
  #      service = "bluesky-pds"
  #      port    = 80
  #    }
  #  }
}
