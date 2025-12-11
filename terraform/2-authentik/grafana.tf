resource "authentik_provider_oauth2" "grafana" {
  name               = "Grafana"
  client_id          = "grafana"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://grafana.local.m1xxos.tech/login/generic_oauth",
    }
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
}

resource "authentik_application" "grafana" {
  name              = "Grafana"
  slug              = "grafana"
  protocol_provider = authentik_provider_oauth2.grafana.id
  meta_icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/grafana.svg"
}

resource "authentik_group" "grafana_admins" {
  name = "Grafana Admins"
}

resource "authentik_group" "grafana_editors" {
  name = "Grafana Editors"
}

resource "authentik_group" "grafana_viewers" {
  name = "Grafana Viewers"
}

resource "vault_kv_secret_v2" "grafana-auth" {
  name  = "grafana/grafana-auth"
  mount = "main"
  data_json = jsonencode(
    {
      oidc_client_id     = authentik_provider_oauth2.grafana.client_id
      oidc_client_secret = authentik_provider_oauth2.grafana.client_secret
    }
  )
}
