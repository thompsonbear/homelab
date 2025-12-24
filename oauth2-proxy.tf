resource "random_password" "oauth_cookie_secrets" {
  for_each         = local.oauth_proxy_workloads
  length           = 32
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create a forward auth middleware to internally forward requests to the oauth proxy auth endpoint
# Response is either 401-403 (Unauthenticated/Unauthorized) or 202 (Authorized)
resource "kubectl_manifest" "oauth2_proxy_forwardauth_middlewares" {
  depends_on = [kubectl_manifest.ingress_manifests]
  for_each   = local.oauth_proxy_workloads

  yaml_body = templatefile("./templates/traefik-forward-auth-middleware.yaml.tmpl", {
    name            = "oauth2-proxy-forwardauth"
    namespace       = each.value.namespace
    forward_address = "http://${each.key}-oauth2-proxy.${each.value.namespace}/oauth2/auth"
  })
}

# Create an errors middleware to redirect the user to the login page if a 401/403 is recieved
resource "kubectl_manifest" "oauth2_proxy_errors_middlewares" {
  depends_on = [helm_release.ingress_charts]
  for_each   = local.oauth_proxy_workloads

  yaml_body = templatefile("./templates/traefik-errors-middleware.yaml.tmpl", {
    name      = "oauth2-proxy-errors"
    namespace = each.value.namespace
    key       = each.key
  })
}

# Preset the oauth2-proxy configmaps
resource "kubectl_manifest" "oauth2_proxy_configs" {
  depends_on = [data.talos_cluster_health.this]
  for_each   = local.oauth_proxy_workloads

  yaml_body = templatefile("./templates/oauth2-proxy-config.yaml.tmpl", {
    name          = "${each.key}-oauth2-proxy"
    namespace     = each.value.namespace
    redirect_url  = "https://${each.value.fqdn}/oauth2/callback"
    allowed_roles = "[\"bear-admin\", \"${each.key}:admin\"]"
    insecure      = var.insecure
  })
}

# Deploy oauth2-proxy for each proxied oauth workload
resource "helm_release" "oauth2_proxies" {
  depends_on = [keycloak_openid_client.workload_clients]
  for_each   = local.oauth_proxy_workloads

  name       = "${each.key}-oauth2-proxy"
  namespace  = each.value.namespace
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "9.0.0"
  values = [
    file("./helm/oauth2-proxy-values.yaml")
  ]

  set = [{
    name  = "config.clientID"
    value = "${each.key}"
    }, {
    name  = "config.clientSecret"
    value = random_password.oauth_client_secrets[each.key].result
    }, {
    name  = "config.cookieSecret"
    value = random_password.oauth_cookie_secrets[each.key].result
    }, {
    name  = "config.cookieName"
    value = "${each.key}-oauth2-proxy"
    }, {
    name  = "config.existingConfig"
    value = "${each.key}-oauth2-proxy"
    }, {
    name  = "ingress.hosts[0]"
    value = each.value.fqdn
    }, {
    name  = "ingress.tls[0].secretName"
    value = "${each.key}-tls"
    }, {
    name  = "ingress.tls[0].hosts[0]"
    value = each.value.fqdn
  }]
}

