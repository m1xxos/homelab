data "authentik_flow" "default-source-authentication" {
  slug = "default-source-authentication"
}
data "authentik_flow" "default-source-enrollment" {
  slug = "default-source-enrollment"
}

locals {
  consumer_key    = data.vault_kv_secret_v2.github-oauth.data.consumer_key
  consumer_secret = data.vault_kv_secret_v2.github-oauth.data.consumer_secret
}

resource "authentik_source_oauth" "github" {
  name                = "github"
  slug                = "github"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = data.authentik_flow.default-source-enrollment.id

  provider_type   = "github"
  consumer_key    = local.consumer_key
  consumer_secret = local.consumer_secret
  oidc_jwks_url = "https://token.actions.githubusercontent.com/.well-known/jwks"
}
