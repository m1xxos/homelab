data "authentik_certificate_key_pair" "vault" {
  name = "vault"
}

resource "random_password" "vault-auth-secret" {
  length = 30
}

resource "authentik_provider_oauth2" "vault" {
  name               = "vault"
  client_id          = "vault"
  client_secret      = random_password.vault-auth-secret.result
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  sub_mode           = "user_username"
  signing_key        = data.authentik_certificate_key_pair.vault.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.profile.id
  ]
  allowed_redirect_uris = [{
    matching_mode = "strict",
    url           = "${var.vault_address}/ui/vault/auth/oidc/oidc/callback"
    },
    {
      matching_mode = "strict",
      url           = "${var.vault_address}/oidc/callback"
    },
    {
      matching_mode = "strict",
      url           = "http://localhost:8250/oidc/callback"
    }
  ]
}

resource "authentik_application" "vault" {
  name              = "vault"
  slug              = "vault"
  protocol_provider = authentik_provider_oauth2.vault.id
  meta_icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/hashicorp-vault.svg"
}

resource "vault_kv_secret_v2" "authentik-auth" {
  name      = "authentik-auth"
  mount     = "user-secrets"
  data_json = jsonencode(
    {
      oidc_client_id     = authentik_provider_oauth2.vault.client_id
      oidc_client_secret = authentik_provider_oauth2.vault.client_secret
    }
  )
}

resource "authentik_group" "admin" {
  name = "admin"
}
