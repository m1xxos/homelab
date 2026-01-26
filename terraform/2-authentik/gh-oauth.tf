data "authentik_flow" "default-source-authentication" {
  slug = "default-source-authentication"
}
data "authentik_flow" "default-source-enrollment" {
  slug = "default-source-enrollment"
}

resource "authentik_source_oauth" "name" {
  name                = "github"
  slug                = "github"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = data.authentik_flow.default-source-enrollment.id

  provider_type   = "github"
  consumer_key    = ephemeral.vault_kv_secret_v2.github-oauth.consumer_key.data.token
  consumer_secret = ephemeral.vault_kv_secret_v2.github-oauth.consumer_secret.data.token
}
