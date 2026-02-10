# Homelab Architecture Reference for coding agents

## Overview

Multi-cluster Kubernetes homelab managed via GitOps (Flux CD) with Talos Linux, deployed on Proxmox.

## Clusters

| Cluster | Role | VIP | External IP | Clustermesh IP | Cilium ID |
|---------|------|-----|-------------|----------------|-----------|
| main | Management | 192.168.1.75 | 192.168.1.80 | 192.168.1.81 | 1 |
| gitlab | Workload | — | 192.168.1.30 | 192.168.1.31 | 2 |

## Infrastructure

- **OS**: Talos Linux (v1.12.2)
- **Provisioning**: Terraform → Proxmox VMs → Talos config → bootstrap
- **CNI**: Cilium (kube-proxy disabled, kubeProxyReplacement: true)
- **GitOps**: Flux CD (bootstrapped from Terraform)
- **Secrets**: HashiCorp Vault + External Secrets Operator (ESO) + SOPS
- **DNS**: Cloudflare (managed via Terraform)
- **Ingress**: Traefik (Gateway API)
- **Auth**: Authentik (OIDC)
- **Monitoring**: VictoriaMetrics k8s stack + OpenTelemetry
- **Storage**: Longhorn (ReadWriteMany)

## Repository Structure

```
terraform/
  0-infra/              — Proxmox VMs, Talos clusters, Cilium bootstrap, Flux bootstrap
    talos-cluster-module/ — Reusable module (cluster.tf, helm.tf, flux.tf, dns.tf, vm.tf)
  1-vault/              — Vault configuration (KV engines, auth backends, policies)
  2-authentik/          — Authentik OIDC configuration

infra/
  tenant/               — Base tenant setup (namespaces, SAs, RBAC, SOPS secrets)
                          Uses ${CLUSTER_NAME} variable
  controllers/          — Shared controllers (cert-manager, ESO, longhorn, traefik, prom-crds)
  configs/              — Shared configs (ClusterSecretStore, ExternalSecrets, certificates)
                          Uses ${DNS_NAME}, ${CILIUM_CLUSTER_NAME}, ${CILIUM_CLUSTERMESH_ENDPOINT}
  critical/             — Critical infra (cilium, ccm, metrics-server) — deployed to remote clusters
                          Uses ${CILIUM_CLUSTER_NAME}, ${CILIUM_CLUSTER_ID}, ${CILIUM_CLUSTERMESH_ENDPOINT}

clusters/
  main/                 — Main cluster Flux entry point
    configs/            — config-sync.yaml (defines main-tenant, main-infra, main-configs kustomizations)
    monitoring/         — VictoriaMetrics stack, OpenTelemetry
    vault/              — Vault Helm release
  main-configs/         — Main cluster configs (applied by main-configs kustomization)
    authentik/          — Authentik SecretStore + ExternalSecret
    cilium/             — Clustermesh ExternalSecrets + global svc
    gitlab-cluster/     — GitOps definition for the gitlab cluster
    monitoring/         — Global vmsingle service
    unified-configs/    — References ../../infra/configs (shared)
  gitlab-tenant/        — GitLab cluster tenant (references infra/tenant)
  gitlab/               — GitLab cluster controllers
  gitlab-configs/       — GitLab cluster configs
    cilium/             — Clustermesh ExternalSecrets + IP pools + L2 announcements
    monitoring/         — VMAgent (remote write to main), global vmsingle stub service
    unified-configs/    — References ../../infra/configs (shared)
```

## Flux Kustomization Hierarchy

### Main Cluster
```
config-sync.yaml (flux-system namespace):
  main-tenant     → infra/tenant       (CLUSTER_NAME=main-cluster)
  main-infra      → infra/controllers  (depends: main-tenant)
  main-configs    → clusters/main-configs (depends: main-infra)
                    Variables: DNS_NAME=local.m1xxos.tech
                              CILIUM_CLUSTER_NAME=main
                              CILIUM_CLUSTERMESH_ENDPOINT=192.168.1.81
```

### GitLab Cluster (managed from main)
```
gitlab-flux.yaml (gitlab-cluster namespace):
  gitlab-cluster-tenant   → clusters/gitlab-tenant  (CLUSTER_NAME=gitlab-cluster, kubeConfig)
  gitlab-cluster-critical → infra/critical           (depends: tenant)
                            Variables: CILIUM_CLUSTER_NAME=gitlab
                                       CILIUM_CLUSTER_ID=2
                                       CILIUM_CLUSTERMESH_ENDPOINT=192.168.1.31
                            Patches: HelmRelease → kubeConfig + serviceAccountName
  gitlab-cluster-infra    → clusters/gitlab          (depends: tenant, critical)
                            Patches: HelmRelease → kubeConfig + serviceAccountName + namespace
  gitlab-cluster-configs  → clusters/gitlab-configs   (depends: tenant, critical)
                            Variables: DNS_NAME=gl.m1xxos.tech
                                       CILIUM_CLUSTER_NAME=gitlab
                                       CILIUM_CLUSTERMESH_ENDPOINT=192.168.1.31
```

## Vault Configuration

### KV Engines
| Engine | Path | Description |
|--------|------|-------------|
| general | general/ | Shared across clusters (cloudflare token, DHI registry, clustermesh certs) |
| main | main/ | Main cluster specific (authentik, grafana, minio) |
| user-secrets | user-secrets/ | User secrets |

### Auth Backends
| Backend | Path | Type | Used by |
|---------|------|------|---------|
| cluster-general | cluster-general | AppRole | ESO ClusterSecretStore (vault-general) on both clusters |
| kubernetes | kubernetes | Kubernetes | Authentik, Minio, Grafana SecretStores on main |

### Policies
| Policy | Access |
|--------|--------|
| general-reader | Read general/data/*, Write general/data/clustermesh/* (for PushSecret) |
| authentik-reader | Read main/data/authentik/* |
| minio-reader | Read main/data/minio/* |
| grafana-reader | Read main/data/grafana/* |

## Cilium Clustermesh

### Architecture (with KVStoreMesh)
```
Agent → local-* certs → KVStoreMesh → remote certs → Remote cluster etcd
```
KVStoreMesh acts as a local cache/proxy — agents never connect directly to remote clusters.

### TLS
- Method: `helm` (auto-generated by Helm, stored in k8s secrets)
- `extraIpAddresses` includes the clustermesh LoadBalancer IP for SANs
- Hubble uses same `helm` method; cluster.name is embedded in cert CN
- If certs have wrong SANs, delete the secrets and let Helm regenerate:
  `kubectl delete secret -n kube-system hubble-server-certs hubble-relay-client-certs hubble-relay-server-certs`
  (Helm `lookup` preserves existing secrets — deletion forces regeneration)

### Secret Flow
```
Each cluster:
  PushSecret (infra/configs/cilium/push-secret.yaml)
    → reads: clustermesh-apiserver-remote-cert (created by Cilium)
    → pushes to: Vault general/clustermesh/${CILIUM_CLUSTER_NAME}
    → data: connection config + ca.crt + tls.crt + tls.key

  ExternalSecret (per-cluster, clusters/<name>-configs/cilium/)
    cilium-kvstoremesh ← Vault clustermesh/<remote-cluster>
    cilium-clustermesh  = static Secret pointing to local kvstoremesh
```

### Adding a New Cluster (e.g. dev, id=3, mesh IP=192.168.1.41)

1. **PushSecret** — automatic via infra/configs (uses ${CILIUM_CLUSTER_NAME})
2. **Flux variables** — add to new cluster's kustomizations:
   - CILIUM_CLUSTER_NAME=dev, CILIUM_CLUSTER_ID=3, CILIUM_CLUSTERMESH_ENDPOINT=192.168.1.41
3. **New cluster** — create `clusters/dev-configs/cilium/`:
   - `external-secret-kvstoremesh.yaml`: dataFrom with all remote clusters
   - `external-secret-clustermesh.yaml`: static Secret with all remote cluster names
4. **Existing clusters** — update their ExternalSecrets to add `clustermesh/dev`

## Monitoring

- **Main cluster**: VictoriaMetrics k8s stack (VMSingle + VMAgent + Grafana)
- **GitLab cluster**: VMAgent only → remote write to main via Cilium global service
- **Global service**: `vmsingle-vm-global` (service.cilium.io/global annotation)
  - Main: has selector pointing to vmsingle pods
  - GitLab: stub service without selector, Cilium provides remote backends

## Terraform Module: talos-cluster-module

### Key Variables
| Variable | Default | Description |
|----------|---------|-------------|
| cluster_name | homelab | Cluster name (used in Cilium, DNS, Flux) |
| cluster_id | 1 | Cilium cluster ID |
| clustermesh_endpoint | (required) | LB IP for clustermesh-apiserver |
| cilium_version | 1.18.6 | Cilium Helm chart version |
| external_ip | 192.168.1.250 | Traefik LoadBalancer IP |
| cp_vip_address | (required) | Control plane VIP |

### Dependency Chain
```
Proxmox VMs → Talos config → bootstrap → kubeconfig
  → helm: cilium (templatefile with cluster_name, cluster_id, clustermesh_endpoint)
    → k8s_manifest: CiliumLoadBalancerIPPool
    → helm: metrics-server
    → helm: talos-ccm
      → flux_bootstrap_git
```

### cilium-values.yaml
Uses Terraform templatefile syntax: `${cluster_name}`, `${cluster_id}`, `${clustermesh_endpoint}`
(vs Flux uses: `${CILIUM_CLUSTER_NAME}`, `${CILIUM_CLUSTER_ID}`, `${CILIUM_CLUSTERMESH_ENDPOINT}`)
