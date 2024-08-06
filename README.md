
<h1 align="center">
  <br>
  <br>
  Homelab
  <br>
</h1>

<h4 align="center">My homelab </h4>

## Key Features

* Ubuntu base vms build with Packer
* Deployed on proxmox with Terraform
* Provisioned by Ansible
* Kubernetes with k3s
* GitOps systems with Portainer and ArgoCD

## Architecture diagram

![Alt text](/architecture-v2.png?raw=true "Architecture")

## Made with

This software uses the following open source packages:

### Virtualization

* Proxmox
* Docker
* Ubuntu Cloud init
* Maas

### IaC tools

* Packer
* Terraform
* Ansible
* Crossplane

### k8s systems

* k3s
* Helm
* ArgoCD
* ClusterAPI
* Traefik
* Cert-manager
* Nfs file provisioner
* MetalLB

### Docker systems

* Portainer GitOps
* Nginx proxy manager
* Keepalived
* HAproxy
* Clodflare tunnel
* Twingate
* SornarQube
* Arrstack with monitoring

### Monitoring

* Prometheus
* Grafana
* AlertManager
* Loki
* Alloy
* FluentBit

### Git

* GitLab
* GitHub actions
* Linters

## Architecture diagram v1

![Alt text](/architecture.png?raw=true "Title")
