resource "harbor_robot_account" "terraform" {
  name        = "K8s-sa"
  description = "K8s sa account"
  level       = "system"
  duration    = -1

  permissions {
    kind      = "system"
    namespace = "/"

    access {
      action   = "manage"
      resource = "catalog"
    }
  }

  permissions {
    kind      = "project"
    namespace = "*"

    access {
      action   = "push"
      resource = "repository"
    }
    access {
      action   = "pull"
      resource = "repository"
    }
    access {
      action   = "delete"
      resource = "repository"
    }
    access {
      action   = "create"
      resource = "tag"
    }
    access {
      action   = "delete"
      resource = "tag"
    }
    access {
      action   = "create"
      resource = "artifact-label"
    }
    access {
      action   = "create"
      resource = "scan"
    }
  }
}
