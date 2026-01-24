data "infisical_secrets" "main" {
    env_slug = "prod"
    folder_path = "/"
    workspace_id = var.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_api_url" {
    name = "proxmox_api_url"
    env_slug = "prod"
    folder_path = "/"
    workspace_id = var.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_api_token_id" {
    name = "proxmox_api_token_id"
    env_slug = "prod"
    folder_path = "/"
    workspace_id = var.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_api_token" {
    name = "proxmox_api_token"
    env_slug = "prod"
    folder_path = "/"
    workspace_id = var.infisical_workspace_id
}
