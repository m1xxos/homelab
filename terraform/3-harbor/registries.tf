resource "harbor_registry" "dockerhub" {
  name          = "dockerhub"
  provider_name = "docker-hub"
  endpoint_url  = "https://hub.docker.com"
  description   = "Proxy cache registry for dockerhub"
}

resource "harbor_registry" "ghcr" {
  name          = "ghcr"
  provider_name = "github"
  endpoint_url  = "https://ghcr.io"
  description   = "Proxy cache registry for ghcr"
}

resource "harbor_registry" "quay" {
  name          = "quay"
  provider_name = "docker-registry"
  endpoint_url  = "https://quay.io"
  description   = "Proxy cache registry for quay"
}

resource "harbor_registry" "k8s_gcr" {
  name          = "k8s_gcr"
  provider_name = "docker-registry"
  endpoint_url  = "https://registry.k8s.io"
  description   = "Proxy cache registry for k8s_gcr"
}

resource "harbor_registry" "mcr" {
  name          = "mcr"
  provider_name = "docker-registry"
  endpoint_url  = "https://mcr.microsoft.com"
  description   = "Proxy cache registry for mcr"
}

resource "harbor_registry" "gcr" {
  name          = "gcr"
  provider_name = "docker-registry"
  endpoint_url  = "https://gcr.io"
  description   = "Proxy cache registry for gcr"
}
