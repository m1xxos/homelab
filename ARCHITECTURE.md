# Homelab Architecture Reference for coding agents

## Overview

Multi-cluster Kubernetes homelab managed via GitOps (Flux CD) with Talos Linux, deployed on Proxmox.

## Clusters

| Cluster | Role | VIP | External IP | Clustermesh IP | Cilium ID |
|---------|------|-----|-------------|----------------|-----------|
| main | Management | 192.168.1.75 | 192.168.1.80 | 192.168.1.81 | 1 |
| gitlab | Workload (CAPI-managed) | 192.168.1.20 | 192.168.1.30 | 192.168.1.31 | 2 |

### GitLab Cluster Details (CAPI / Talos / Proxmox)
| Property | Value |
|----------|-------|
| CAPI cluster name | `proxmox-gitlab` |
| Management namespace | `gitlab-cluster` (on main) |
| Kubernetes version | v1.35.0 |
| Talos version | v1.12.2 |
| CP replicas | 1 (4 CPU / 4 GiB / 30 GB) |
| Worker replicas | 1 (4 CPU / 4 GiB / 30 GB) |
| Proxmox node | `plusha`, template ID `110` |
| Pod CIDR | 10.168.0.0/16 |
| Worker IP range | 192.168.1.21–192.168.1.30 |
| OIDC | Authentik at `https://authentik.local.m1xxos.tech/application/o/k8s/`, client `k8s` |

## Infrastructure

- **OS**: Talos Linux (v1.12.2)
- **Provisioning**: Terraform → Proxmox VMs → Talos config → bootstrap
- **CNI**: Cilium v1.18.6 (kube-proxy disabled, kubeProxyReplacement: true, L2 announcements, KVStoreMesh)
- **GitOps**: Flux CD (bootstrapped from Terraform, SOPS decryption via `sops-gpg`)
- **Secrets**: HashiCorp Vault (HA Raft, 3 replicas, YC KMS auto-unseal) + ESO + SOPS
- **DNS**: Cloudflare (managed via Terraform), domains: `local.m1xxos.tech` (main), `gl.m1xxos.tech` (gitlab)
- **Ingress**: Traefik v38.0.1 (Gateway API + experimental channel for TCPRoute/TLSRoute)
- **Auth**: Authentik v2025.12.4 (OIDC)
- **Monitoring**: VictoriaMetrics k8s stack v0.63.2 + OpenTelemetry Collector v0.142.0
- **Logging**: Loki (distributed mode, embedded MinIO)
- **Tracing**: Tempo v1.24.1
- **Storage**: Longhorn (ReadWriteMany, NFS backup to 192.168.1.138)
- **Object Storage**: SeaweedFS v4.0.412 (S3-compatible, COSI)
- **Database**: CloudNative-PG v0.26.1
- **Cache/Redis**: Dragonfly Operator v1.4.0+

## Repository Structure

```
terraform/
  0-infra/              — Proxmox VMs, Talos clusters, Cilium bootstrap, Flux bootstrap
    talos-cluster-module/ — Reusable module (cluster.tf, helm.tf, flux.tf, dns.tf, vm.tf)
  1-vault/              — Vault configuration (KV engines, auth backends, policies, random passwords)
  2-authentik/          — Authentik OIDC configuration (Grafana, K8s providers)

infra/
  tenant/               — Base tenant setup (namespaces, SAs, RBAC, SOPS secrets)
                          Uses ${CLUSTER_NAME} variable
                          Creates: flux-restricted SA, flux-cluster-admin SA (→ cluster-admin),
                          oidc-cluster-admin binding (k8s-admins group → cluster-admin),
                          namespaces (cert-manager, external-secrets, longhorn-system, traefik),
                          Vault SOPS secrets (vault-rid, vault-sid in external-secrets ns)
  controllers/          — Shared controllers:
                          cert-manager, external-secrets, longhorn, traefik,
                          prom-crds, gateway-api (TCPRoute CRD v1.4.1 experimental)
  configs/              — Shared configs:
                          ClusterSecretStore vault-general (Vault at https://vault.local.m1xxos.tech,
                            mount general, AppRole auth with SOPS-encrypted RoleID/SecretID),
                          ClusterIssuer (Let's Encrypt ACME via Cloudflare DNS01 for *.m1xxos.tech),
                          Certificate (wildcard local.m1xxos.tech + *.local.m1xxos.tech in traefik ns),
                          Cloudflare token ExternalSecret, DHI secret ExternalSecret,
                          Cilium PushSecret, volume-snapshotter CRD + controller
                          Uses ${DNS_NAME}, ${CILIUM_CLUSTER_NAME}, ${CILIUM_CLUSTERMESH_ENDPOINT}
  critical/             — Critical infra deployed to remote clusters:
                          cilium v1.18.6, talos-ccm v0.5.2, metrics-server v3.13.0
                          Uses ${CILIUM_CLUSTER_NAME}, ${CILIUM_CLUSTER_ID}, ${CILIUM_CLUSTERMESH_ENDPOINT}

clusters/
  main/                 — Main cluster Flux entry point
    configs/            — config-sync.yaml (3-stage: main-tenant → main-infra → main-configs)
                          CiliumL2AnnouncementPolicy, CiliumLoadBalancerIPPool (192.168.1.81)
    monitoring/         — VictoriaMetrics stack, OpenTelemetry Collector
    vault/              — Vault Helm release (HA Raft, 3 replicas, YC KMS unseal)
    authentik/          — Authentik HelmRelease (CNPG backend)
    cloudnative-pg/     — CNPG operator HelmRelease
    dragonfly/          — Dragonfly operator HelmRelease + instances
    seaweedfs/          — SeaweedFS HelmRelease (S3 with COSI + IAM auth)
    logs/               — Loki HelmRelease (distributed, embedded MinIO)
    tracing/            — Tempo HelmRelease
    capi-operator-system/ — Cluster API Operator (Talos bootstrap/CP, Proxmox infra)
  main-configs/         — Main cluster configs
    authentik/          — Authentik SecretStore + ExternalSecret
    capi/               — CAPI provider manifests
    cilium/             — Clustermesh ExternalSecrets + global svc
    etcd/               — etcd backup CronJob (talos-backup → MinIO S3 at 192.168.1.77:9000)
    gitlab-cluster/     — CAPI cluster definition + CNPG gitlab-rails-db + gitlab-flux.yaml
    gitlab/             — PushSecret (DB password), BucketClaims (13 COSI buckets)
    longhorn/           — Backup target (NFS), recurring jobs, volume snapshots
    monitoring/         — Global vmsingle service (Cilium global)
    seaweedfs/          — SeaweedFS S3 IAM config ESO
    traefik/            — IngressRoute (dashboard), HTTPRoutes (hubble UI, vault UI)
    unified-configs/    — References ../../infra/configs (shared)
  gitlab-tenant/        — GitLab cluster tenant
    unified/            — References ../../infra/tenant
    namespaces/         — gitlab namespace
    global-svc/         — Cilium global service stubs (gitlab-rails-db-global-rw)
  gitlab/               — GitLab cluster controllers
    gitlab/             — GitLab HelmRelease v9.9.0 (CE) + values ConfigMap
    monitoring/         — VMAgent (remote write to main via Cilium global svc)
    unified-controllers/ — References ../../infra/controllers
  gitlab-configs/       — GitLab cluster configs
    cilium/             — Clustermesh ExternalSecrets + IP pools + L2 announcements
    external-secrets/   — ExternalSecrets (Dragonfly password)
    gitlab/             — ExternalSecrets (DB password, object storage creds)
    monitoring/         — VMAgent config, global vmsingle stub service
    unified-configs/    — References ../../infra/configs (shared)
```

## Flux Kustomization Hierarchy

### Main Cluster
```
config-sync.yaml (flux-system namespace):
  main-tenant     → infra/tenant       (CLUSTER_NAME=main-cluster, SOPS decryption: sops-gpg)
  main-infra      → infra/controllers  (depends: flux-system, main-tenant)
  main-configs    → clusters/main-configs (depends: main-infra)
                    Variables: DNS_NAME=local.m1xxos.tech
                              CILIUM_CLUSTER_NAME=main
                              CILIUM_CLUSTERMESH_ENDPOINT=192.168.1.81
```

### GitLab Cluster (managed from main via CAPI)
```
gitlab-flux.yaml (gitlab-cluster namespace, kubeConfig: proxmox-gitlab-kubeconfig):
  gitlab-cluster-tenant   → clusters/gitlab-tenant  (CLUSTER_NAME=gitlab-cluster)
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

## GitLab Deployment

### GitLab Helm Chart v9.9.0
| Property | Value |
|----------|-------|
| Edition | CE (Community Edition) |
| HelmRelease namespace | `gitlab-cluster` (remote target: `gitlab`) |
| Values source | ConfigMap `gitlab-values` (label `reconcile.fluxcd.io/watch: Enabled`) |

**Hostnames:**
| Service | Hostname |
|---------|----------|
| Web + SSH | gl.m1xxos.tech |
| Registry | registry.gl.m1xxos.tech |
| KAS | kas.gl.m1xxos.tech |
| Pages | pages.gl.m1xxos.tech |

**External services (bundled charts disabled):**
| Service | Backend | Host | Port | Auth Secret |
|---------|---------|------|------|-------------|
| PostgreSQL | CNPG `gitlab-rails-db` | `gitlab-rails-db-global-rw.gitlab` | 5432 | `gitlab-rails-db-app` (key: `password`) |
| Redis | Dragonfly `dragonfly-gl` | `dragonfly-gl.gitlab` | 6379 | `dragonfly-gl` (key: `password`) |
| Object Storage | SeaweedFS S3 | `http://seaweedfs-s3.seaweedfs.svc:8333` | 8333 | `gitlab-object-storage` (keys: `config`, `s3cmd`) |

**Ingress:** Gateway API (`gatewayRef: traefik-gateway` in namespace `traefik`), nginx-ingress disabled.

**Disabled bundled sub-charts:** Redis, PostgreSQL, MinIO, nginx-ingress, cert-manager.

**Gitaly persistence:** 15 GiB

### CloudNative-PG (PostgreSQL)
| Property | Value |
|----------|-------|
| Operator chart | `cloudnative-pg` v0.26.1 |
| Operator namespace | `cnpg-system` |
| Cluster name | `gitlab-rails-db` |
| Cluster namespace | `gitlab-cluster` (on main) |
| Instances | 1 |
| Image | `ghcr.io/cloudnative-pg/postgresql:17` |
| Storage | 3 GiB |
| Database | `gitlabhq_production` |
| Owner | `gitlab` |
| Extensions | `pg_trgm`, `btree_gist`, `plpgsql`, `amcheck`, `pg_stat_statements` |
| Global service | `gitlab-rails-db-global-rw` annotated `service.cilium.io/global: "true"` |

**DB password flow:**
```
CNPG auto-generates → Secret gitlab-rails-db-app (in gitlab-cluster ns)
  → PushSecret gitlab-rails-db-push → Vault general/gitlab-rails-db-password
  → ExternalSecret gitlab-rails-db-app (in gitlab ns on gitlab cluster) ← Vault
  → GitLab reads global.psql.password.secret: gitlab-rails-db-app
```

### Dragonfly (Redis replacement)
| Property | Value |
|----------|-------|
| Operator chart | `dragonfly-operator` (OCI from `ghcr.io/dragonflydb/dragonfly-operator`) |
| Instance name | `dragonfly-gl` |
| Instance namespace | `gitlab` |
| Replicas | 2 |
| Resources | 500m–600m CPU, 300–550 Mi memory |
| Auth secret | `dragonfly-gl` (key: `password`) |
| Global service | annotated `service.cilium.io/global: "true"` |

**Password flow:**
```
Terraform random_password (60 char) → Vault general/dragonfly-gl-password
  → ExternalSecret dragonfly-gl (on both clusters) ← Vault
  → GitLab reads global.redis.host: dragonfly-gl.gitlab, secret: dragonfly-gl
```

### SeaweedFS (S3 Object Storage)
| Property | Value |
|----------|-------|
| Chart | `seaweedfs` v4.0.412 |
| Namespace | `seaweedfs` |
| Volume replicas | 2 (3 GiB PVC each) |
| Master PVC | 1 GiB |
| Filer PVC | 1 GiB |
| S3 auth | enabled, config via secret `seaweedfs-s3-config` |
| COSI | enabled (`bucketClassName: seaweedfs`) |
| S3 global service | annotated `service.cilium.io/global: "true"` |
| S3 endpoint | `http://seaweedfs-s3.seaweedfs.svc:8333` |

**S3 IAM config** (`seaweedfs-s3-config` ExternalSecret in `seaweedfs` ns):
- Pulls `aws_access_key_id` / `aws_secret_access_key` from Vault key `gitlab-object-storage`
- Templates JSON IAM config with identity `gitlab` having permissions: `Admin, Read, Write, List, Tagging`

**COSI BucketClaims** (namespace `gitlab`, protocol S3):
`git-lfs`, `gitlab-artifacts`, `gitlab-backups`, `gitlab-ci-secure-files`, `gitlab-dependency-proxy`,
`gitlab-mr-diffs`, `gitlab-packages`, `gitlab-pages`, `gitlab-terraform-state`, `gitlab-uploads`,
`registry`, `runner-cache`, `tmp`

**S3 credentials flow:**
```
Terraform random_string (20 char access key) + random_password (40 char secret key)
  → Vault general/gitlab-object-storage (keys: aws_access_key_id, aws_secret_access_key, bucket_region=us-east-1)
  → ExternalSecret gitlab-object-storage (gitlab ns): produces config (Rails YAML) + s3cmd (.s3cfg)
  → ExternalSecret seaweedfs-s3-config (seaweedfs ns): produces IAM JSON for SeaweedFS
```

### Authentik OIDC SSO
| Property | Value |
|----------|-------|
| Provider | Authentik at `https://authentik.m1xxos.tech/application/o/gitlab` |
| Client ID/Secret | Terraform `authentik_provider_oauth2.gitlab` → Vault `main/gitlab/gitlab-auth` |
| K8s secret | `gitlab-authentik-oidc` (namespace `gitlab`, key: `provider`) |
| ESO source | `clusters/main-configs/gitlab/gitlab-authentik-oidc.yaml` |
| Helm config | `global.appConfig.omniauth.providers[0].secret: gitlab-authentik-oidc` |

**OIDC credentials flow:**
```
Terraform random_password + authentik_provider_oauth2.gitlab
  → Vault main/gitlab/gitlab-auth (keys: oidc_client_id, oidc_client_secret)
  → ExternalSecret gitlab-authentik-oidc (gitlab ns): produces provider YAML
  → GitLab reads omniauth.providers[0].secret: gitlab-authentik-oidc, key: provider
```

**omniauth settings:** `autoSignInWithProvider: openid_connect`, `blockAutoCreatedUsers: false`,
`autoLinkUser: [openid_connect]`, `allowSingleSignOn: [openid_connect]`.

### Cilium ClusterMesh — Cross-Cluster Global Services
| Service | Namespace | Port | Purpose |
|---------|-----------|------|---------|
| `dragonfly-gl` | `gitlab` | 6379/TCP | Redis |
| `gitlab-rails-db-global-rw` | `gitlab` | 5432/TCP | PostgreSQL RW |
| `seaweedfs-s3` | `seaweedfs` | 8333/TCP | S3 object storage |
| `vmsingle-vm-global` | `monitoring` | 8428/TCP | VictoriaMetrics (for GitLab cluster VMAgent) |

Mirror service stubs exist in `clusters/gitlab-tenant/global-svc/`.

## Vault Configuration

### Deployment
| Property | Value |
|----------|-------|
| Chart | Local `./assets/vault` (from Git) |
| Namespace | `vault` |
| HA mode | 3 replicas, Raft storage |
| Cluster name | `main-vault` |
| Auto-unseal | Yandex Cloud KMS (key `abjc7mkspu26rij5khdc`) |
| UI | Exposed via HTTPRoute at `vault.local.m1xxos.tech` |

### KV Engines
| Engine | Path | Description |
|--------|------|-------------|
| general | general/ | Shared across clusters (cloudflare, DHI, clustermesh certs, dragonfly, gitlab S3 creds) |
| main | main/ | Main cluster specific (authentik, grafana OIDC, minio) |
| user-secrets | user-secrets/ | User secrets |

### Key Vault Secrets
| Vault Path | Created By | Consumed By |
|------------|------------|-------------|
| general/cloudflare-token | Manual | ESO → cert-manager DNS01 |
| general/clustermesh/${name} | PushSecret (Cilium) | ESO → Cilium KVStoreMesh |
| general/gitlab-rails-db-password | PushSecret (CNPG) | ESO → GitLab psql |
| general/dragonfly-gl-password | Terraform random_password | ESO → GitLab redis, Dragonfly auth |
| general/gitlab-object-storage | Terraform random_string + random_password | ESO → GitLab object store, SeaweedFS IAM |
| main/gitlab/gitlab-auth | Terraform (Authentik provider) | ESO → GitLab omniauth OIDC (client_id, client_secret) |
| main/grafana/grafana-auth | Terraform (Authentik OIDC) | Vault Agent sidecar → Grafana |
| main/minio/access-token | Manual | ESO → etcd backup CronJob |
| main/authentik/* | Terraform | ESO → Authentik |

### Auth Backends
| Backend | Path | Type | Used by |
|---------|------|------|---------|
| cluster-general | cluster-general | AppRole | ESO ClusterSecretStore (vault-general) on both clusters |
| kubernetes | kubernetes | Kubernetes | Authentik, GitLab, Minio, Grafana SecretStores on main |

### Policies
| Policy | Access |
|--------|--------|
| general-reader | Read general/data/*, Write general/data/clustermesh/* (for PushSecret) |
| authentik-reader | Read main/data/authentik/* |
| gitlab-reader | Read main/data/gitlab/* |
| minio-reader | Read main/data/minio/* |
| grafana-reader | Read main/data/grafana/* |

## Traefik (Gateway API)

| Property | Value |
|----------|-------|
| Chart | `traefik` v38.0.1 |
| Namespace | `traefik` |
| Gateway API | enabled, experimentalChannel: true (for TCPRoute/TLSRoute) |
| Gateway API CRDs | `infra/controllers/gateway-api/` (TCPRoute CRD v1.4.1 experimental) |
| Kubernetes Ingress | disabled |
| Kubernetes CRD | enabled, allowExternalNameServices: true |

**Gateway Listeners:**
| Listener | Port | Protocol | Namespaces |
|----------|------|----------|------------|
| web | 8000 | HTTP | All |
| websecure | 8443 | HTTPS | All |

**TLS:** Secret `local-m1xxos-tech` (wildcard cert from cert-manager: `local.m1xxos.tech` + `*.local.m1xxos.tech`)

**Exposed Services (via HTTPRoute through `traefik-gateway`):**
| App | Hostname |
|-----|----------|
| Grafana | grafana.local.m1xxos.tech |
| VMAgent | vmagent.local.m1xxos.tech |
| Vault | vault.local.m1xxos.tech |
| Authentik | authentik.local.m1xxos.tech |
| Hubble UI | hubble.local.m1xxos.tech |
| Longhorn UI | longhorn.local.m1xxos.tech |
| Traefik Dashboard | traefik.local.m1xxos.tech (IngressRoute) |
| GitLab | gl.m1xxos.tech (on gitlab cluster) |
| Registry | registry.gl.m1xxos.tech |
| KAS | kas.gl.m1xxos.tech |
| Pages | pages.gl.m1xxos.tech |

**Tracing:** OTLP gRPC → `tempo.tracing.svc.cluster.local:4317`
**Metrics:** Prometheus (routers + services labels)

## Authentik (Identity Provider)

| Property | Value |
|----------|-------|
| Chart | `authentik` v2025.12.4 |
| Namespace | `authentik` |
| PostgreSQL | CNPG cluster `authentik-new-rw` (secret: `authentik-new-app`) |
| Redis | Embedded (redis.enabled: true) |
| Secret key | From Secret `authentik-secret-key` mounted at `/secret-key/secret-key` |
| UI | HTTPRoute at `authentik.local.m1xxos.tech` |
| SA | `authentik-reader` |

**OIDC consumers:**
- Grafana (generic_oauth, group mapping: `Grafana Admins`→Admin, `Grafana Editors`→Editor)
- Kubernetes RBAC (`k8s-admins` group → `cluster-admin` via oidc-cluster-admin ClusterRoleBinding)

## Observability Stack

### VictoriaMetrics k8s Stack
| Property | Value |
|----------|-------|
| Chart | `victoria-metrics-k8s-stack` v0.63.2 |
| Namespace | `monitoring` |
| VMSingle | 5 GiB storage (RWX), OTel prometheus naming, Cilium global service |
| VMAgent | Exposed at `vmagent.local.m1xxos.tech` |
| Grafana | 5 GiB PVC, exposed at `grafana.local.m1xxos.tech`, Vault Agent sidecar for OIDC creds |
| Node Exporter + KSM | enabled |

**Grafana datasources:**
- VictoriaMetrics (default)
- Loki at `http://loki-gateway.logging.svc.cluster.local` (trace→log correlation)
- Tempo at `http://tempo.tracing.svc.cluster.local:3200` (trace→log/metric correlation)

### OpenTelemetry Collector
| Property | Value |
|----------|-------|
| Chart | `opentelemetry-collector` v0.142.0 |
| Mode | DaemonSet (contrib image, runs on control-plane nodes) |
| Receivers | OTLP gRPC (:4317), OTLP HTTP (:4318) |
| Metrics pipeline | OTLP → deltatocumulative → VMSingle at `http://vmsingle-vm.monitoring.svc.cluster.local:8428/opentelemetry/v1/metrics` |
| Logs pipeline | OTLP → Loki at `http://loki-gateway.logging.svc.cluster.local/otlp` |
| Presets | logsCollection, kubernetesAttributes |

### Loki (Distributed)
| Property | Value |
|----------|-------|
| Namespace | `logging` |
| Mode | Distributed (3 ingesters, 3 queriers, 2 query-frontend, 2 query-scheduler, 3 distributors, 1 compactor, 2 index-gateways) |
| Storage | Embedded MinIO, S3-compatible, schema v13/TSDB |
| Config | auth_enabled: false, chunk_encoding: snappy, chunksCache: 2048MB, bloom: disabled |
| Gateway | ClusterIP at `http://loki-gateway.logging.svc.cluster.local` |

### Tempo (Tracing)
| Property | Value |
|----------|-------|
| Chart | `tempo` v1.24.1 |
| Namespace | `tracing` |
| Persistence | 5 GiB PV |
| Endpoint | `http://tempo.tracing.svc.cluster.local:3200` |

### GitLab Cluster Monitoring
- VMAgent only → remote write to main via Cilium global service `vmsingle-vm-global`
- Stub service without selector in gitlab cluster, Cilium provides remote backends

## Longhorn Storage

| Property | Value |
|----------|-------|
| Namespace | `longhorn-system` |
| Backup target | NFS at `nfs://192.168.1.138:/mnt/main/lh-backup`, poll interval 300s |
| Recurring jobs | `full-backup` (every 3h, retain 1), `system-backup` (every 3h, retain 1), `full-trim` (every 3h) |
| UI | HTTPRoute at `longhorn.local.m1xxos.tech` |
| VolumeSnapshotClass | `longhorn-backup-vsc` (full backup mode) |
| Snapshots | authentik-2 PVC in authentik namespace |

## etcd Backup

| Property | Value |
|----------|-------|
| CronJob | `talos-backup` (every 30 min `0/30 * * * *`) |
| Image | `ghcr.io/siderolabs/talos-backup:v0.1.0-beta.3-5-g07d09ec` |
| Target | MinIO S3 at `http://192.168.1.77:9000`, bucket `talos-etcd` |
| Encryption | AGE with X25519 public key |
| Compression | zstd |
| Cluster name | `main` |
| Creds | ESO `minio-access-token` → SecretStore `minio-store` → Vault `main/minio/access-token` (K8s auth, role `minio-reader`) |

## CAPI Operator

| Property | Value |
|----------|-------|
| Chart | `cluster-api-operator` v0.24.0 |
| Namespace | `capi-operator-system` |
| Providers | Bootstrap: Talos, ControlPlane: Talos, Infrastructure: Proxmox |

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

## Secret Summary

| K8s Secret | Namespace | Source | Keys | Consumer |
|------------|-----------|--------|------|----------|
| `gitlab-object-storage` | `gitlab` | ESO ← Vault `gitlab-object-storage` | `config`, `s3cmd` | GitLab object store + backups |
| `gitlab-authentik-oidc` | `gitlab` | ESO ← Vault `gitlab/gitlab-auth` | `provider` | GitLab omniauth OIDC |
| `gitlab-rails-db-app` | `gitlab` | ESO ← Vault `gitlab-rails-db-password` | `password` | GitLab psql |
| `dragonfly-gl` | `gitlab` | ESO ← Vault `dragonfly-gl-password` | `password` | GitLab redis, Dragonfly auth |
| `seaweedfs-s3-config` | `seaweedfs` | ESO ← Vault `gitlab-object-storage` | `seaweedfs_s3_config` | SeaweedFS S3 IAM |
| `gitlab-rails-db-push` | `gitlab` | PushSecret → Vault `gitlab-rails-db-password` | `password` | Vault (destination) |
| `local-m1xxos-tech` | `traefik` | cert-manager (Let's Encrypt + Cloudflare DNS01) | tls.crt, tls.key | Traefik HTTPS |
| `authentik-new-app` | `authentik` | CNPG auto-generated | password, etc | Authentik PG |
| `authentik-secret-key` | `authentik` | ESO ← Vault | secret-key | Authentik app |
| `vault-key` | `vault` | SOPS | - | Vault HelmRelease |
| `vault-rid`, `vault-sid` | `external-secrets` | SOPS | - | ClusterSecretStore AppRole auth |

All ExternalSecrets use **ClusterSecretStore** `vault-general`, Vault KV v2 mount `general`, refresh interval 1h.
`gitlab-authentik-oidc` uses namespace **SecretStore** `gitlab-store`, Vault KV v2 mount `main` (K8s auth, role `gitlab-reader`).

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

## Cross-Component Dependency Map
```
Flux GitOps (config-sync)
 ├─► infra/tenant (namespaces, RBAC, Vault SOPS secrets)
 ├─► infra/controllers (cert-manager, ESO, traefik, longhorn, gateway-api, prom-crds)
 ├─► infra/critical (cilium, talos-ccm, metrics-server)
 └─► clusters/main-configs + clusters/main/*

Vault (HA Raft, YC KMS auto-unseal)
 ├─► ESO (ClusterSecretStore vault-general, AppRole auth)
 ├─► Grafana (Vault Agent sidecar for OIDC creds)
 └─► etcd backup (MinIO creds via ESO → Vault K8s auth)

Authentik (OIDC IdP)
 ├─► Grafana SSO (generic_oauth)
 ├─► K8s RBAC (k8s-admins → cluster-admin)
 └─► PostgreSQL (CNPG cluster authentik-new-rw)

Traefik Gateway (listeners: HTTP/8000, HTTPS/8443)
 ├─► HTTPRoutes: Grafana, VMAgent, Authentik, Vault, Hubble, Longhorn (*.local.m1xxos.tech)
 ├─► HTTPRoutes: GitLab, Registry, KAS, Pages (*.gl.m1xxos.tech)
 ├─► TCPRoute: gitlab-shell SSH (requires experimental channel CRDs)
 └─► TLS: wildcard cert *.local.m1xxos.tech (Let's Encrypt + Cloudflare DNS01)

OTEL Collector (DaemonSet)
 ├─► Metrics → VictoriaMetrics (VMSingle)
 └─► Logs → Loki (gateway)

Grafana Datasources
 ├─► VictoriaMetrics (metrics, default)
 ├─► Loki (logs, trace→log correlation)
 └─► Tempo (traces, trace→log/metric correlation)

GitLab (on gitlab cluster) → external services on main cluster via Cilium ClusterMesh:
 ├─► PostgreSQL: gitlab-rails-db-global-rw.gitlab:5432
 ├─► Redis: dragonfly-gl.gitlab:6379
 └─► S3: seaweedfs-s3.seaweedfs:8333
```
