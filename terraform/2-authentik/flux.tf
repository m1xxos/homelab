resource "authentik_provider_proxy" "flux" {
  name = "flux"
  mode = "forward_single"
  external_host = "https://flux.local.m1xxos.online"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow = data.authentik_flow.default-invalidation-flow.id
}

resource "authentik_application" "flux" {
  name              = "Flux"
  slug              = "flux"
  protocol_provider = authentik_provider_proxy.flux.id
  meta_icon         = "https://cdn.jsdelivr.net/gh/selfhst/icons@main/svg/flux-operator.svg"
}

resource "authentik_policy_expression" "k8s_admins" {
  name = "flux_binding"
  expression = "return ak_is_group_member(request.user, name=\"k8s-admins\")"
}

resource "authentik_policy_binding" "flux_binding" {
  target = authentik_application.flux.uuid
  policy = authentik_policy_expression.k8s_admins.id
  order = 0
}
