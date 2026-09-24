system = {
  cert_manager = { chart_tag = "1.21.1" }
  metallb      = { chart_tag = "0.16.1" }
  istio        = { chart_tag = "1.30.3" }
  csi_nfs      = { chart_tag = "4.13.4" }
  mayastor     = { chart_tag = "2.11.1" }
  keycloak = { image_tag = "26.7.2" }
  cnpg = {
    operator = {
      image_tag = "1.30.0"
      chart_tag = "0.29.0"
      pg_images = [{
        major = 15
        image = "ghcr.io/cloudnative-pg/postgresql:15.19-202608170814-minimal-trixie@sha256:67b23fdf6dbf3d5bc5dc42cdbc5d292375582b1fe378c1dc69eb51c6fbc57730"
        }, {
        major = 16
        image = "ghcr.io/cloudnative-pg/postgresql:16.15-202608170814-minimal-trixie@sha256:e3041d59a94c072fa2fd4436b82ecdf34afc9d38c8cf2b836b009b09a1744c63"
        }, {
        major = 17
        image = "ghcr.io/cloudnative-pg/postgresql:17.11-202608170816-minimal-trixie@sha256:445ead3fd811466950a002b682a97c2a4907078b46fae8796b6637a763266a07"
        }, {
        major = 18
        image = "ghcr.io/cloudnative-pg/postgresql:18.6-202608170814-minimal-trixie@sha256:eb7979e4bd7fccaec0369b550b9649eec1f014de04621fac6e653244e75cca46"
        extensions = [{
          name                   = "vchord"
          image                  = { reference = "ghcr.io/tensorchord/vchord-scratch:pg18-v1.1.1" }
          dynamic_library_path   = ["/usr/lib/postgresql/18/lib/"]
          extension_control_path = ["/usr/share/postgresql/18/"]
          }, {
          name  = "pgvector"
          image = { reference = "ghcr.io/cloudnative-pg/pgvector:0.8.6-202609071550-18-trixie@sha256:a2b828fe19d3c65138fc9308530dc2104eafa9b12ab6dc29a15c6432c1bebfe0" }
        }]
      }]
    }
  }
  valkey = {
    operator = {
      chart_tag = "0.6.0"
    }
    chart_tag = "0.12.0"
  }
}
