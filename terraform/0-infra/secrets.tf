data "infisical_secrets" "main" {
  env_slug     = "prod"
  folder_path  = "/"
  workspace_id = var.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_api_url" {
  name         = "proxmox_api_url"
  env_slug     = local.infisical_env_slug
  folder_path  = local.infisical_folder_path
  workspace_id = local.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_api_token_id" {
  name         = "proxmox_api_token_id"
  env_slug     = local.infisical_env_slug
  folder_path  = local.infisical_folder_path
  workspace_id = local.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_api_token" {
  name         = "proxmox_api_token"
  env_slug     = local.infisical_env_slug
  folder_path  = local.infisical_folder_path
  workspace_id = local.infisical_workspace_id
}

ephemeral "infisical_secret" "proxmox_ssh_password" {
  name         = "proxmox_ssh_password"
  env_slug     = local.infisical_env_slug
  folder_path  = local.infisical_folder_path
  workspace_id = local.infisical_workspace_id
}

ephemeral "infisical_secret" "cloudflare_api_token" {
  name         = "cloudflare_api_token"
  env_slug     = local.infisical_env_slug
  folder_path  = local.infisical_folder_path
  workspace_id = local.infisical_workspace_id
}

locals {
  infisical_env_slug      = "prod"
  infisical_folder_path   = "/"
  infisical_workspace_id  = var.infisical_workspace_id
  cloudflare_zone_id      = data.infisical_secrets.main.secrets["cloudflare_zone_id"].value
  github_token            = data.infisical_secrets.main.secrets["github_token"].value
}