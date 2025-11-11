data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_provider_oauth2" "name" {
  name               = "vault"
  client_id          = "vault"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow = data.authentik_flow.default-invalidation-flow.id
}
