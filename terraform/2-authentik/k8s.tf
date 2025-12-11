resource "authentik_provider_oauth2" "k8s" {
  name               = "k8s"
  client_id          = "k8s"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "http://localhost:8000"
    }
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
  sub_mode                   = "user_username"
  include_claims_in_id_token = true
}

resource "authentik_application" "k8s" {
  name              = "k8s"
  slug              = "k8s"
  protocol_provider = authentik_provider_oauth2.k8s.id
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/kubernetes.svg"
}

resource "authentik_group" "k8s-admins" {
  name = "k8s-admins"
}