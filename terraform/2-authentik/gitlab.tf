resource "random_password" "gitlab-auth-secret" {
  length = 30
}

resource "authentik_provider_oauth2" "gitlab" {
  name               = "gitlab"
  client_id          = "gitlab"
  client_secret      = random_password.gitlab-auth-secret.result
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  sub_mode           = "user_email"
  signing_key        = data.authentik_certificate_key_pair.vault.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.email.id,
  ]
  allowed_redirect_uris = [{
    matching_mode = "strict",
    url           = "https://gl.m1xxos.tech/users/auth/openid_connect/callback"
    }
  ]
}

resource "authentik_application" "gitlab" {
  name              = "gitlab"
  slug              = "gitlab"
  protocol_provider = authentik_provider_oauth2.gitlab.id
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/gitlab.svg"
}

resource "vault_kv_secret_v2" "gitlab-auth" {
  name  = "gitlab/gitlab-auth"
  mount = "main"
  data_json = jsonencode(
    {
      oidc_client_id     = authentik_provider_oauth2.gitlab.client_id
      oidc_client_secret = authentik_provider_oauth2.gitlab.client_secret
    }
  )
}
