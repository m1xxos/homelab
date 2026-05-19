resource "random_password" "harbor-auth-secret" {
  length = 30
}

resource "authentik_provider_oauth2" "harbor" {
  name               = "harbor"
  client_id          = "harbor"
  client_secret      = random_password.harbor-auth-secret.result
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  sub_mode           = "user_email"
  signing_key        = data.authentik_certificate_key_pair.vault.id

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.email.id,
  ]

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://harbor.local.m1xxos.online/c/oidc/callback"
    }
  ]
}

resource "authentik_application" "harbor" {
  name              = "harbor"
  slug              = "harbor"
  protocol_provider = authentik_provider_oauth2.harbor.id
}

resource "authentik_group" "harbor-admins" {
  name = "harbor-admins"
}

resource "vault_kv_secret_v2" "harbor-auth" {
  name  = "harbor/harbor-auth"
  mount = "main"
  data_json = jsonencode(
    {
      oidc_client_id     = authentik_provider_oauth2.harbor.client_id
      oidc_client_secret = authentik_provider_oauth2.harbor.client_secret
    }
  )
}
