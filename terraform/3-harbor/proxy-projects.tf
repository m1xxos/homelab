resource "harbor_project" "dockerhub_proxy" {
  name        = "proxy-dockerhub"
  registry_id = harbor_registry.dockerhub.registry_id
}

resource "harbor_project" "ghcr_proxy" {
  name        = "proxy-ghcr"
  registry_id = harbor_registry.ghcr.registry_id
}

resource "harbor_project" "quay_proxy" {
  name        = "proxy-quay"
  registry_id = harbor_registry.quay.registry_id
}

resource "harbor_project" "k8s_gcr_proxy" {
  name        = "proxy-k8s-gcr"
  registry_id = harbor_registry.k8s_gcr.registry_id
}

resource "harbor_project" "bitnami_proxy" {
  name        = "proxy-bitnami"
  registry_id = harbor_registry.bitnami.registry_id
}

resource "harbor_project" "jetbrains_proxy" {
  name        = "proxy-jetbrains"
  registry_id = harbor_registry.jetbrains.registry_id
}

resource "harbor_project" "mcr_proxy" {
  name        = "proxy-mcr"
  registry_id = harbor_registry.mcr.registry_id
}
