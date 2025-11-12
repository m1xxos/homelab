data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

resource "random_password" "vault-auth-secret" {
  length = 30
}

resource "authentik_provider_oauth2" "name" {
  name               = "vault"
  client_id          = "vault"
  client_secret      = random_password.vault-auth-secret.result
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
}
