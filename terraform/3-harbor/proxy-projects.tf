resource "harbor_project" "dockerhub_proxy" {
  name        = "dockerhub"
  public      = true
  registry_id = harbor_registry.dockerhub.registry_id
}

resource "harbor_project" "ghcr_proxy" {
  name        = "ghcr"
  public      = true
  registry_id = harbor_registry.ghcr.registry_id
}

resource "harbor_project" "quay_proxy" {
  name        = "quay"
  public      = true
  registry_id = harbor_registry.quay.registry_id
}

resource "harbor_project" "k8s_gcr_proxy" {
  name        = "k8s-gcr"
  public      = true
  registry_id = harbor_registry.k8s_gcr.registry_id
}

resource "harbor_project" "mcr_proxy" {
  name        = "mcr"
  public      = true
  registry_id = harbor_registry.mcr.registry_id
}

resource "harbor_project" "gcr_proxy" {
  name        = "gcr"
  public      = true
  registry_id = harbor_registry.gcr.registry_id
}
