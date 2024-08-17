data "authentik_flow" "default-provider-authorization-implicit-consent" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_scope_mapping" "scope-email" {
  name = "authentik default OAuth Mapping: OpenID 'email'"
}

data "authentik_scope_mapping" "scope-profile" {
  name = "authentik default OAuth Mapping: OpenID 'profile'"
}

data "authentik_scope_mapping" "scope-openid" {
  name = "authentik default OAuth Mapping: OpenID 'openid'"
}

resource "authentik_provider_oauth2" "portainer" {
  name          = "Portainer"
  #  Required. You can use the output of:
  #     $ openssl rand -hex 16
  client_id     = "fc3bd22b101241863cd8d0c6c89f8006"

  # Optional: will be generated if not provided
  # client_secret = "my_client_secret"

  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id

  redirect_uris = ["https://portainer.local.m1xxos.me/"]

  property_mappings = [
    data.authentik_scope_mapping.scope-email.id,
    data.authentik_scope_mapping.scope-profile.id,
    data.authentik_scope_mapping.scope-openid.id,
  ]
}

resource "authentik_application" "portainer" {
  name              = "Portainer"
  slug              = "portainer"
  protocol_provider = authentik_provider_oauth2.portainer.id
}

resource "authentik_group" "Portainer_admins" {
  name    = "Portainer Admins"
}
