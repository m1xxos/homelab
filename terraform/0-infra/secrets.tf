data "infisical_secrets" "main" {
    env_slug = "prod"
    folder_path = "/"
    workspace_id = var.infisical_workspace_id
}