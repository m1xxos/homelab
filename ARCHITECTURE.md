# Homelab Architecture Reference for coding agents

_Last updated: 2026-06-16 (reflects repository changes through 2026-06-16)_

## Overview

Single-cluster Kubernetes homelab managed via GitOps (Flux CD) with Talos Linux, deployed on Proxmox.
The active cluster is `main` (all workloads). GitLab and the dedicated app/test clusters were removed
in May 2026; additional CAPI-managed clusters can still be provisioned on demand via `task new-cluster`.

## Cluster: main

| Property | Value |
|----------|-------|
| Role | All workloads (management + apps) |
| Control plane VIP | 192.168.1.75 |
| External/L2 IP | 192.168.1.80 |
| ClusterMesh IP | 192.168.1.81 (clustermesh-apiserver LB; mesh enabled, no live peers) |
| Cilium ID | 1 |
| CP nodes | 1 × `main-cp-0` (192.168.1.70), 6 GiB RAM |
| Worker nodes | 3 × `main-worker-{0,1,2}` (192.168.1.10–12), 4 cores / 5 GiB RAM / 70 GiB disk each |
| Kubernetes version | v1.35.0 |
| Talos version | v1.12.2 (initial image 1.11.3 via factory.talos.dev) |
| OIDC | Authentik at `https://authentik.local.m1xxos.online/application/o/k8s/`, client `k8s` |

Proxmox node: `plusha` (192.168.1.122), VM disks on `pve-nvme` datastore, `cache=writeback`,
`iothread`, `virtio-scsi-single`. The host disk subsystem is the known weak spot — an I/O stall on
the host previously took down `main-worker-1` (VM 911); mitigations: Longhorn `engineReplicaTimeout=30`,
single-replica StorageClass for reproducible data, `vm.swappiness=30` set manually on the host
(**not** persisted in IaC — reapply after host reinstall).

## Infrastructure

- **OS**: Talos Linux (v1.12.2)
- **Provisioning**: Terraform → Proxmox VMs → Talos config → bootstrap
- **CNI**: Cilium v1.18.6 (kube-proxy disabled, kubeProxyReplacement: true, L2 announcements;
  ClusterMesh enabled in the Terraform cilium-values template — clustermesh-apiserver runs on `main`,
  but no live peer clusters yet)
- **GitOps**: Flux CD (bootstrapped from Terraform, branch `main`, SOPS decryption via `sops-gpg`)
- **Secrets**: HashiCorp Vault (HA Raft, 3 replicas, YC KMS auto-unseal) + ESO + SOPS
- **DNS**: Cloudflare (managed via Terraform), domain: `local.m1xxos.online`
- **Ingress**: Traefik v40.2.0 (Gateway API + experimental channel)
- **Auth**: Authentik v2026.2.0 (OIDC)
- **Monitoring**: VictoriaMetrics k8s stack v0.72.2 + Grafana Operator (OCI, semver >=5.22.2) + node-exporter (DHI OCI chart >=4.55.0)
- **Logging**: VictoriaLogs VLSingle (3d retention, 10 GiB) + OTel Collector DaemonSet (filelog)
- **Tracing**: VictoriaTraces VTSingle (3d retention, 10 GiB) + OTel Collector Deployment (OTLP/Jaeger/Zipkin)
- **OTel**: opentelemetry-operator v0.114.1 (namespace `logging`), collectors as `OpenTelemetryCollector` CRs
- **Storage**: Longhorn v1.10.0 (default class 2 replicas best-effort + `longhorn-single` class, NFS backup to 192.168.1.138)
- **Object Storage**: SeaweedFS v4.0.413 (S3-compatible, COSI) — currently has no in-cluster consumers (was GitLab's backend)
- **Database**: CloudNative-PG v0.27.1
- **Cache/Redis**: Dragonfly Operator
- **Registry**: Harbor (chart v1.19.0) with external CNPG PostgreSQL + Dragonfly Redis

## Repository Structure

```
terraform/
  0-infra/              — Proxmox VMs, Talos clusters, Cilium bootstrap, Flux bootstrap
    talos-cluster-module/ — Reusable module (cluster.tf, helm.tf, flux.tf, dns.tf, vm.tf)
  1-vault/              — Vault configuration (KV engines, auth backends, policies, random passwords)
  2-authentik/          — Authentik OIDC configuration (Grafana, Harbor, K8s, GitHub-oauth providers)

infra/
  tenant/               — Base tenant setup (namespaces, SAs, RBAC, SOPS secrets)
                          Uses ${CLUSTER_NAME} variable
                          Creates: flux-restricted SA, flux-cluster-admin SA (→ cluster-admin),
                          oidc-cluster-admin binding (k8s-admins group → cluster-admin),
                          namespaces (cert-manager, external-secrets, longhorn-system, traefik,
                          monitoring, logging),
                          Vault SOPS secrets (vault-rid, vault-sid in external-secrets ns)
  controllers/          — Shared controllers:
                          cert-manager v1.19.2, external-secrets v0.20.4, longhorn v1.10.0,
                          traefik v40.2.0, prom-crds v25.0.0, node-exporter (DHI OCI),
                          opentelemetry-operator v0.114.1
  configs/              — Shared configs:
                          ClusterSecretStore vault-general (Vault at https://vault.local.m1xxos.online,
                            mount general, AppRole auth with SOPS-encrypted RoleID/SecretID),
                          ClusterIssuer (Let's Encrypt ACME via Cloudflare DNS01 for *.m1xxos.online),
                          Certificate (wildcard local.m1xxos.online + *.local.m1xxos.online in traefik ns),
                          Cloudflare token ExternalSecret, DHI secret ExternalSecret,
                          longhorn-single StorageClass (1 replica, best-effort locality),
                          OTel logging collector (DaemonSet CR → VLSingle),
                          volume-snapshotter CRD + controller, Traefik dashboard/hubble/longhorn routes
                          Uses ${DNS_NAME}
  critical/             — Critical infra deployed to remote clusters (none active now):
                          cilium v1.18.6, talos-ccm v0.5.2, metrics-server v3.13.0
                          Uses ${CILIUM_CLUSTER_NAME}, ${CILIUM_CLUSTER_ID}, ${CILIUM_CLUSTERMESH_ENDPOINT}

clusters/
  main/                 — Main cluster Flux entry point
    namespaces/         — Cluster namespaces (`authentik`, `harbor`, `monitoring`, `vault`, `tracing`, etc.)
    flux-system/        — Flux components/sync manifests (GitRepository branch: main)
    flux-configs/       — config-sync.yaml (`main-tenant` → `main-controllers` → `main-configs`)
    configs/            — CiliumL2AnnouncementPolicy, CiliumLoadBalancerIPPool (192.168.1.81, clustermesh — reserved)
  main-controllers/     — Main cluster controllers:
                          Authentik, CNPG operator, Cluster API Operator v0.25.0, Dragonfly operator,
                          Harbor, VictoriaMetrics stack + Grafana Operator, SeaweedFS, Vault
    unified-controllers/ — References ../../../infra/controllers (shared controllers layer)
  main-configs/         — Main cluster configs
    authentik/          — Authentik SecretStore + ExternalSecret + CNPG cluster (authentik-new)
    capi/               — CAPI provider manifests (Proxmox provider, IPAM)
    etcd/               — etcd backup CronJob (talos-backup → MinIO S3 at 192.168.1.77:9000)
    grafana/            — Grafana CRs (instance, datasources VM/VL/VT, dashboards, route, SecretStore)
    harbor/             — Harbor route, ESO secrets (admin, OIDC values), CNPG harbor-pg,
                          Dragonfly harbor-dragonfly + scrape NetworkPolicy, VM scraper
    logging/            — VLSingle `main` (3d, 10 GiB) + HTTPRoute vl.${DNS_NAME}
    longhorn/           — Backup target (NFS), recurring jobs, volume snapshots
    monitoring/         — VM scrapes/alerts (CNPG, Traefik, Longhorn, Authentik)
    seaweedfs/          — SeaweedFS S3 IAM config ESO + admin UI route (seadm.${DNS_NAME})
    tracing/            — VTSingle `main` (3d, 10 GiB) + OTel tracing collector (Deployment)
    traefik/            — Vault UI IngressRoute
    unified-configs/    — References ../../infra/configs (shared)
```

## Flux Kustomization Hierarchy

```
clusters/main/flux-configs/config-sync.yaml (flux-system namespace on main cluster):
  main-tenant      → infra/tenant              (CLUSTER_NAME=main-cluster, SOPS decryption: sops-gpg)
  main-controllers → clusters/main-controllers (CLUSTER_NAME=main; includes unified-controllers → infra/controllers)
  main-configs     → clusters/main-configs     (depends: main-controllers)
                      Variables: DNS_NAME=local.m1xxos.online
                                CILIUM_CLUSTER_NAME=main
                                CILIUM_CLUSTERMESH_ENDPOINT=192.168.1.81
```

For CAPI-managed remote clusters a separate `<cluster>-flux.yaml` is created in the management
namespace — see **Adding a New Cluster** section below.

## Harbor (Container Registry)

| Property | Value |
|----------|-------|
| Chart | `harbor` v1.19.0 |
| Namespace | `harbor` |
| URL | `https://harbor.local.m1xxos.online` (HTTPRoute, expose type clusterIP, TLS off at pod level) |
| Admin password | ESO `harbor-admin-secret` ← Vault `main/harbor/admin` |
| OIDC | Authentik (`oidc_admin_group: harbor-admins`), config injected via ESO `harbor-oidc-values` ← Vault `main/harbor/harbor-auth` |
| PostgreSQL | CNPG cluster `harbor-pg` (1 instance, 5 GiB), service `harbor-pg-rw.harbor` |
| Redis | Dragonfly `harbor-dragonfly` (1 replica, no auth, NetworkPolicy allows scrape from monitoring) |
| Persistence | registry 10 GiB + trivy 5 GiB on `longhorn-single` (trivy = cache, registry covered by NFS recurring backup) |
| Metrics | VMPodScrape (harbor-scraper, cnpg-harbor-pod-scraper) |

Harbor SecretStore `harbor-store` uses Vault K8s auth (role `harbor-reader`, SA `harbor-reader`, mount `main`).

## Vault Configuration

### Deployment
| Property | Value |
|----------|-------|
| Chart | Local `./assets/vault` (from Git) |
| Namespace | `vault` |
| HA mode | 3 replicas, Raft storage, 2 GiB PVC each |
| Cluster name | `main-vault` |
| Auto-unseal | Yandex Cloud KMS (key `abjc7mkspu26rij5khdc`) |
| UI | Exposed via IngressRoute at `vault.local.m1xxos.online` |

### KV Engines
| Engine | Path | Description |
|--------|------|-------------|
| general | general/ | Shared across clusters (cloudflare token, DHI creds, SeaweedFS S3 creds) |
| main | main/ | Main cluster specific (authentik, grafana OIDC, harbor, minio) |
| user-secrets | user-secrets/ | User secrets |

### Key Vault Secrets
| Vault Path | Created By | Consumed By |
|------------|------------|-------------|
| general/cloudflare-token | Manual | ESO → cert-manager DNS01 |
| general/gitlab-object-storage | Terraform random_string + random_password | ESO → SeaweedFS S3 IAM (name is legacy — these are now just the SeaweedFS credentials) |
| main/harbor/admin | Terraform | ESO → Harbor admin password |
| main/harbor/harbor-auth | Terraform (Authentik provider) | ESO → Harbor OIDC values |
| main/grafana/grafana-auth | Terraform (Authentik OIDC) | ESO `grafana-oauth` → Grafana env vars |
| main/minio/access-token | Manual | ESO → etcd backup CronJob |
| main/authentik/* | Terraform | ESO → Authentik secret key |

### Auth Backends
| Backend | Path | Type | Used by |
|---------|------|------|---------|
| cluster-general | cluster-general | AppRole | ESO ClusterSecretStore (vault-general) |
| kubernetes | kubernetes | Kubernetes | Authentik, Harbor, Minio, Grafana SecretStores |
| oidc | oidc | OIDC (Authentik) | Human access to Vault UI |

### Policies
| Policy | Access |
|--------|--------|
| general-reader | Read general/data/* (+ write general/data/clustermesh/* — used by the mesh PushSecret) |
| authentik-reader | Read main/data/authentik/* |
| harbor-reader | Read main/data/harbor/* |
| minio-reader | Read main/data/minio/* |
| grafana-reader | Read main/data/grafana/* |
| users-reader | Read user-secrets/data/* |

## Traefik (Gateway API)

| Property | Value |
|----------|-------|
| Chart | `traefik` v40.2.0 |
| Namespace | `traefik` |
| Gateway API | enabled, experimentalChannel: true |
| Kubernetes Ingress provider | enabled |
| Kubernetes CRD | enabled, allowExternalNameServices: true |

**Gateway Listeners:**
| Listener | Port | Protocol | Namespaces |
|----------|------|----------|------------|
| web | 8000 | HTTP | All |
| websecure | 8443 | HTTPS | All |

**TLS:** Secret `local-m1xxos` (wildcard cert from cert-manager: `local.m1xxos.online` + `*.local.m1xxos.online`)

**Exposed Services (via HTTPRoute through `traefik-gateway`):**
| App | Hostname |
|-----|----------|
| Grafana | grafana.local.m1xxos.online |
| VMAgent | vmagent.local.m1xxos.online |
| Vault | vault.local.m1xxos.online (IngressRoute) |
| Authentik | authentik.local.m1xxos.online |
| Harbor | harbor.local.m1xxos.online |
| Hubble UI | hubble.local.m1xxos.online |
| Longhorn UI | longhorn.local.m1xxos.online |
| Traefik Dashboard | traefik.local.m1xxos.online (IngressRoute) |
| VictoriaLogs UI | vl.local.m1xxos.online |
| SeaweedFS Admin | seadm.local.m1xxos.online |

**Tracing:** OTLP gRPC → `tracing-collector.tracing.svc.cluster.local:4317` → OTLP HTTP → VTSingle
**Metrics:** Prometheus (routers + services labels)
**Access logs:** enabled (common format) → collected by the logging DaemonSet

## Authentik (Identity Provider)

| Property | Value |
|----------|-------|
| Chart | `authentik` v2026.2.0 |
| Namespace | `authentik` |
| PostgreSQL | CNPG cluster `authentik-new` (bootstrap: recovery from VolumeSnapshot `authentik-db-backup`), secret `authentik-new-app` |
| Redis | Embedded (redis.enabled: true) |
| Secret key | From Secret `authentik-secret-key` mounted at `/secret-key/secret-key` |
| UI | HTTPRoute at `authentik.local.m1xxos.online` |
| SA | `authentik-reader` |
| Resources | server 800Mi req / 1600Mi lim, worker 1100Mi req / 2000Mi lim (largest app on the cluster) |

**OIDC consumers (Terraform `terraform/2-authentik/`):**
- Grafana (generic_oauth, group mapping: `Grafana Admins`→Admin, `Grafana Editors`→Editor)
- Harbor (`harbor-admins` group → Harbor admin)
- Kubernetes RBAC (`k8s-admins` group → `cluster-admin` via oidc-cluster-admin ClusterRoleBinding)
- Vault (OIDC auth backend)
- GitHub-oauth source

## Observability Stack

### VictoriaMetrics k8s Stack
| Property | Value |
|----------|-------|
| Chart | `victoria-metrics-k8s-stack` v0.72.2 |
| Namespace | `monitoring` |
| VMSingle | retention 3d, 5 GiB RWO on `longhorn-single`, Cilium global svc annotation, OTel prometheus naming |
| VMAgent | `promscrape.maxScrapeSize: 32MiB` (kube-apiserver target), route at `vmagent.local.m1xxos.online` |
| Grafana | Disabled in VM stack (managed by Grafana Operator) |
| node-exporter | Disabled in stack — separate DHI OCI chart (`infra/controllers/node-exporter`, `${CLUSTER_NAME}-node-exporter`) |
| kube-state-metrics | enabled |
| kubeEtcd | Scraped via manual endpoint 192.168.1.70:2381 (Talos `listen-metrics-urls`, unauthenticated metrics-only port) |

### Grafana Operator
| Property | Value |
|----------|-------|
| Chart | `grafana-operator` (OCI `ghcr.io/grafana/helm-charts/grafana-operator`, semver >=5.22.2) |
| Namespace | `monitoring` |
| Grafana CR | `grafana` (`grafana.integreatly.org/v1beta1`), strategy Recreate |
| Storage | 5 GiB PVC `grafana-pvc`, mounted as `grafana-data` (explicit volume override — the operator does **not** mount its own PVC automatically) |
| UI | `grafana.local.m1xxos.online` (HTTPRoute → `grafana-service:3000`) |
| Auth | Authentik OIDC; client id/secret via ESO `grafana-oauth` (SecretStore `grafana-store`, Vault `main/grafana/grafana-auth`, K8s auth role `grafana-reader`) → env vars `$__env{OAUTH_*}` |

**Grafana datasources (GrafanaDatasource CRs):**
- VictoriaMetrics (prometheus type, default) at `http://vmsingle-vm:8428`
- VictoriaLogs (plugin `victoriametrics-logs-datasource` v0.27.1) at `http://vlsingle-main.logging.svc.cluster.local:9428`
- VictoriaTraces (Jaeger type) at `http://vtsingle-main.tracing.svc.cluster.local:10428/select/jaeger`

**Grafana dashboards (GrafanaDashboard CRs):** Kubernetes Views Global/Namespaces/Nodes/Pods (15757–15760),
API Server (15761), Node Exporter Full (1860), Etcd (3070), Dragonfly, SeaweedFS, K8s top pods (custom).

### Logging (VictoriaLogs)
| Property | Value |
|----------|-------|
| Operator | opentelemetry-operator v0.114.1 (namespace `logging`) |
| Collector | `OpenTelemetryCollector` CR `logging`, mode DaemonSet (incl. control-plane toleration) |
| Pipeline | filelog (`/var/log/pods/*/*/*.log`, container parser) → memory_limiter → batch → OTLP HTTP |
| Sink | VLSingle `main` (`logging` ns): retention 3d, 10 GiB PVC on `longhorn-single`, `vlsingle-main.logging:9428` |
| UI | `vl.local.m1xxos.online` |
| Cilium global svc | annotated (for shipping logs from future external clusters) |

### Tracing (VictoriaTraces)
| Property | Value |
|----------|-------|
| Collector | `OpenTelemetryCollector` CR `tracing` (namespace `tracing`), mode Deployment |
| Receivers | OTLP gRPC/HTTP (4317/4318), Jaeger (14250/6831/14268), Zipkin (9411) |
| Processors | k8sattributes (rich pod metadata), memory_limiter, batch |
| Sink | VTSingle `main` (`tracing` ns): retention 3d, 10 GiB PVC on `longhorn-single`, OTLP HTTP `vtsingle-main.tracing:10428/insert/opentelemetry/v1/traces` |
| Query | Jaeger API at `vtsingle-main.tracing:10428/select/jaeger` (Grafana datasource) |

**Trace flow:**
```
Traefik → OTLP gRPC → tracing-collector (:4317) → OTLP HTTP → VTSingle
```

## Longhorn Storage

| Property | Value |
|----------|-------|
| Chart | `longhorn` v1.10.0, namespace `longhorn-system` |
| Default StorageClass | `longhorn`: 2 replicas, dataLocality best-effort |
| Extra StorageClass | `longhorn-single`: 1 replica, best-effort locality, for reproducible/cache data (infra/configs) |
| Stability | `engineReplicaTimeout: 30`, `concurrentReplicaRebuildPerNodeLimit: 1`, `autoCleanupSystemGeneratedSnapshot`, `backupConcurrentLimit: 1`, 10% disk reserved |
| Backup target | NFS at `nfs://192.168.1.138:/mnt/main/lh-backup`, poll interval 300s |
| Recurring jobs | `full-backup` (3h @:00, retain 1, concurrency 1), `snapshot-cleanup` (3h @:15), `snapshot-delete` (3h @:30, retain 1), `system-backup` (6h @:30, retain 2), `full-trim` (6h @:45, concurrency 1) — staggered so backup and trim never fire in the same minute |
| UI | HTTPRoute at `longhorn.local.m1xxos.online` |
| VolumeSnapshotClass | `longhorn-backup-vsc` (full backup mode); snapshot `authentik-db-backup` of `authentik-2` PVC |

## etcd Backup

| Property | Value |
|----------|-------|
| CronJob | `talos-backup` (hourly, `0 * * * *`) |
| Image | `ghcr.io/siderolabs/talos-backup:v0.1.0-beta.3-5-g07d09ec` |
| Target | MinIO S3 at `http://192.168.1.77:9000`, bucket `talos-etcd` |
| Encryption | AGE with X25519 public key; zstd compression |
| Creds | ESO `minio-access-token` → SecretStore `minio-store` → Vault `main/minio/access-token` (K8s auth, role `minio-reader`) |

Note: talos-backup has no built-in retention — old snapshots accumulate in MinIO and need occasional manual pruning.

## SeaweedFS (S3 Object Storage)

| Property | Value |
|----------|-------|
| Chart | `seaweedfs` v4.0.413, namespace `seaweedfs` |
| Topology | master (1 GiB PVC), filer (1 GiB PVC), 2 volume servers (3 GiB PVC each), admin UI, COSI |
| S3 auth | enabled, IAM config via ESO `seaweedfs-s3-config` ← Vault `general/gitlab-object-storage` (identity `gitlab` — legacy name) |
| Endpoints | S3 `seaweedfs-s3.seaweedfs:8333` (Cilium global svc), admin UI `seadm.local.m1xxos.online` |

**Status:** GitLab (the only consumer) was removed in May 2026. The chart no longer creates buckets;
old `gitlab-*` buckets may still hold data in the filer. SeaweedFS is kept for ad-hoc S3 usage —
if that never materializes, removing it frees ~4 pods and ~8 GiB of Longhorn space.

## CAPI Operator

| Property | Value |
|----------|-------|
| Chart | `cluster-api-operator` v0.25.0 |
| Namespace | `capi-operator-system` |
| Providers | Bootstrap: Talos, ControlPlane: Talos, Infrastructure: Proxmox (+ in-cluster IPAM) |

Installed on the management cluster; used only when a new workload cluster is provisioned with `task new-cluster`.

### Proxmox CAPI provisioning

Current CAPI Proxmox manifests are migrated to CAPMOX v0.8 / v1alpha2:

- `ProxmoxCluster` and `ProxmoxMachineTemplate` use `infrastructure.cluster.x-k8s.io/v1alpha2`
- `Cluster` and `MachineDeployment` use `cluster.x-k8s.io/v1beta2`
- CAPI refs use `apiGroup` instead of `apiVersion`
- Proxmox machine networking uses `network.networkDevices` with `net0`
- Talos config remains on `controlplane.cluster.x-k8s.io/v1alpha3` / `bootstrap.cluster.x-k8s.io/v1alpha3`

Provisioning uses the Proxmox API token `capmox@pve!capi` and requires ACLs on:

- `/nodes/plusha` (`PVEAuditor`)
- `/storage/local-lvm` (`PVEAdmin` or equivalent datastore write rights)
- `/storage/pve-nvme` (`PVEAdmin` or equivalent datastore write rights)
- `/storage/local` (`PVEDatastoreAdmin`) — **required for cloud-init**. CAPMOX (via go-proxmox
  `findStorageByContent("iso")`) uploads the cloud-init ISO to the first storage advertising `iso`
  content, which on `plusha` is only `local` (type `dir`; `lvmthin` cannot hold ISOs). Without
  `Datastore.Audit` the token cannot see `local` in the storage list and `Datastore.AllocateTemplate`
  is needed to upload — missing either makes VM provisioning fail with
  `unable to inject CloudInit ISO: unable to find the item you are looking for`. Apply with:
  `pveum acl modify /storage/local --user capmox@pve --role PVEDatastoreAdmin`
- `/sdn` (`PVEAdmin` or equivalent SDN use rights)

These ACLs are applied manually with `pveum` (not managed in Terraform). After a Proxmox host reinstall
or token recreation, reapply all of them — the `/storage/local` grant in particular is easy to miss.

## Adding a New Cluster

```
task new-cluster
```

The interactive script `assets/scripts/new-cluster.sh` collects parameters (name, IPs, CPU/RAM, Cilium ID)
and scaffolds the following files:

```
clusters/main-configs/<name>-cluster/
  namespace.yaml              — Namespace for CAPI objects on main
  <name>-cluster.yaml         — CAPI Cluster + ProxmoxCluster + TalosControlPlane + MachineTemplates
  <name>-flux.yaml            — Flux Kustomizations (tenant → critical → infra → configs)
clusters/<name>-tenant/       — infra/tenant reference (namespaces, RBAC, Vault SOPS secrets)
clusters/<name>/              — Controllers (references infra/controllers)
clusters/<name>-configs/
  cilium/                     — ClusterMesh ExternalSecrets + IP pools + L2 announcements
  unified-configs/            — References infra/configs
terraform/0-infra/            — asks to add Terraform VM/DNS/Talos config
```

After scaffolding:
1. `terraform apply` in `terraform/0-infra/` to create VMs and DNS
2. Commit + push → Flux applies CAPI objects → cluster bootstraps
3. `task add-kubeconfig CLUSTER=<name>` to add OIDC kubeconfig locally
4. Re-enable ClusterMesh (see below) if cross-cluster services are needed

## Cilium ClusterMesh (enabled on main, no live peers)

ClusterMesh is **enabled** on `main` — it is *not* disabled (this section was previously stale):

- The `clustermesh` block in `terraform/0-infra/talos-cluster-module/cilium-values.yaml` is **active**
  (not commented). `main` runs `clustermesh-apiserver` (3/3); `cilium-config` has `cluster-name=main`,
  `cluster-id=1`.
- `infra/configs/cilium/push-secret.yaml` is active and pushes `main`'s mesh cert to Vault
  `general/clustermesh/main` (PushSecret `cilium-clustermesh-push` = Synced).
- `infra/critical/cilium/values.yaml` (remote clusters) also enables clustermesh.
- The LB IP 192.168.1.81 and the `clustermesh-pool` CiliumLoadBalancerIPPool are in use.
- `service.cilium.io/global: "true"` annotations become effective once a real peer joins.

**Known stale data (cleanup pending):** `main`'s peer secrets still reference the removed `gitlab`/`app`
clusters. `clusters/main-configs/cilium/external-secret-kvstoremesh.yaml` extracts Vault
`clustermesh/gitlab` + `clustermesh/app` (dead), and `external-secret-clustermesh.yaml` has a stray
`gitlab` self-entry. These sync without error (the dead Vault paths still exist) but point `main` at
clusters that no longer run. De-stale them when the first real peer joins (so `cilium clustermesh status`
can verify the live peer before the dead ones are dropped).

### Peering model (hub-and-spoke: every cluster ↔ `main`)
- Each cluster (incl. `main`) pushes its own mesh cert to Vault `clustermesh/<name>` via the
  `infra/configs/cilium` PushSecret.
- **Remote → main:** the per-cluster `clusters/<name>-configs/cilium/` (rendered by
  `assets/scripts/scaffold-cluster.sh`) carries a `cilium-kvstoremesh` ExternalSecret pulling
  `clustermesh/main` + a static `cilium-clustermesh` secret — so every new cluster peers with the hub.
- **main → remote:** add the new peer to `main`'s side once the cluster is up and has pushed its cert:
  append `- extract: { key: clustermesh/<name> }` to
  `clusters/main-configs/cilium/external-secret-kvstoremesh.yaml`. (kro can't edit git; this is the one
  manual hub-side touch — also printed by `scaffold-cluster.sh`.)
- TLS method is `helm`; if certs have wrong SANs, delete the hubble/clustermesh secrets and let Helm
  regenerate.

## Secret Summary

| K8s Secret | Namespace | Source | Keys | Consumer |
|------------|-----------|--------|------|----------|
| `local-m1xxos` | `traefik` | cert-manager (Let's Encrypt + Cloudflare DNS01) | tls.crt, tls.key | Traefik HTTPS |
| `authentik-new-app` | `authentik` | CNPG auto-generated | password, etc | Authentik PG |
| `authentik-secret-key` | `authentik` | ESO ← Vault `main/authentik/*` | secret-key | Authentik app |
| `harbor-admin-secret` | `harbor` | ESO ← Vault `main/harbor/admin` | HARBOR_ADMIN_PASSWORD | Harbor |
| `harbor-oidc-values` | `harbor` | ESO ← Vault `main/harbor/harbor-auth` | values.yaml | Harbor HelmRelease (OIDC) |
| `harbor-pg-app` | `harbor` | CNPG auto-generated | password, etc | Harbor DB |
| `grafana-oauth` | `monitoring` | ESO ← Vault `main/grafana/grafana-auth` | oidc_client_id/secret | Grafana OIDC env |
| `seaweedfs-s3-config` | `seaweedfs` | ESO ← Vault `general/gitlab-object-storage` | seaweedfs_s3_config | SeaweedFS S3 IAM |
| `minio-access-token` | `default` | ESO ← Vault `main/minio/access-token` | AWS_* | etcd backup CronJob |
| `dhi-registry` | `monitoring` | ESO ← Vault `general/dhi` | dockerconfigjson | node-exporter OCI pulls |
| `vault-key` | `vault` | SOPS | - | Vault HelmRelease |
| `vault-rid`, `vault-sid` | `external-secrets` | SOPS | - | ClusterSecretStore AppRole auth |

ExternalSecrets default to **ClusterSecretStore** `vault-general` (Vault KV v2 mount `general`, refresh 1h);
app-specific secrets use namespace **SecretStores** (`harbor-store`, `grafana-store`, `authentik-store`,
`minio-store`) with Vault K8s auth and per-app reader roles.

## Terraform Module: talos-cluster-module

### Key Variables
| Variable | Default | Description |
|----------|---------|-------------|
| cluster_name | homelab | Cluster name (used in Cilium, DNS, Flux) |
| cluster_id | 1 | Cilium cluster ID |
| clustermesh_endpoint | (required) | LB IP for clustermesh-apiserver (template var; block currently commented) |
| cilium_version | 1.18.6 | Cilium Helm chart version |
| external_ip | 192.168.1.250 | Traefik LoadBalancer IP |
| cp_vip_address | (required) | Control plane VIP |
| branch | — | Git branch Flux bootstraps from (**must stay `main`**) |

### Dependency Chain
```
Proxmox VMs → Talos config → bootstrap → kubeconfig
  → helm: cilium (templatefile with cluster_name, cluster_id, clustermesh_endpoint)
    → k8s_manifest: CiliumLoadBalancerIPPool
    → helm: metrics-server
    → helm: talos-ccm
      → flux_bootstrap_git
```

### Talos machine config highlights (cluster.tf)
- CNI `none` (Cilium installed by Terraform), kube-proxy disabled
- sysctls: `vm.dirty_background_ratio=5`, `vm.dirty_ratio=10` — smaller writeback bursts towards the
  fragile plusha disk (see Known Issues)
- kubelet: `/var/lib/longhorn` bind mount, external cloud-provider, rotate-server-certificates
- Control plane: bind-address 0.0.0.0 for scheduler/controller-manager, etcd metrics on :2381,
  VIP on physical interface, Talos API access for `os:reader` + `os:etcd:backup`
  (namespaces kube-system, default)

### cilium-values.yaml
Uses Terraform templatefile syntax: `${cluster_name}`, `${cluster_id}`, `${clustermesh_endpoint}`
(vs Flux uses: `${CILIUM_CLUSTER_NAME}`, `${CILIUM_CLUSTER_ID}`, `${CILIUM_CLUSTERMESH_ENDPOINT}`).
The `clustermesh` block is active (clustermesh-apiserver runs on `main`).

## Cross-Component Dependency Map
```
Flux GitOps (config-sync, branch main)
 ├─► infra/tenant (namespaces, RBAC, Vault SOPS secrets)
 ├─► clusters/main-controllers (apps + unified-controllers → infra/controllers)
 └─► clusters/main-configs (+ clusters/main/namespaces and clusters/main/configs via main Flux entrypoint)

Vault (HA Raft, YC KMS auto-unseal)
 ├─► ESO (ClusterSecretStore vault-general AppRole + per-app K8s-auth SecretStores)
 └─► etcd backup (MinIO creds via ESO)

Authentik (OIDC IdP)
 ├─► Grafana SSO (generic_oauth via ESO grafana-oauth)
 ├─► Harbor SSO (oidc_auth via ESO harbor-oidc-values)
 ├─► Vault UI (OIDC auth backend)
 ├─► K8s RBAC (k8s-admins → cluster-admin)
 └─► PostgreSQL (CNPG cluster authentik-new)

Traefik Gateway (listeners: HTTP/8000, HTTPS/8443)
 ├─► HTTPRoutes: Grafana, VMAgent, Authentik, Harbor, Hubble, Longhorn, VictoriaLogs, SeaweedFS admin
 ├─► IngressRoutes: Traefik dashboard, Vault UI
 └─► TLS: wildcard cert *.local.m1xxos.online (Let's Encrypt + Cloudflare DNS01)

Observability
 ├─► metrics: VMAgent → VMSingle ← Grafana (default DS)
 ├─► logs:    OTel DaemonSet (filelog) → VLSingle ← Grafana (VictoriaLogs DS)
 └─► traces:  Traefik → OTel Deployment → VTSingle ← Grafana (Jaeger DS)

Harbor (harbor namespace)
 ├─► PostgreSQL: harbor-pg-rw.harbor:5432 (CNPG)
 ├─► Redis: harbor-dragonfly.harbor:6379 (Dragonfly, 1 replica)
 └─► Storage: Longhorn PVCs (registry 10Gi, trivy 5Gi)
```

## Known Issues / Operational Notes

- **Memory is the cluster bottleneck**, not CPU: node requests run at 66–86%, limits oversubscribed
  up to ~250% on worker-1. Largest consumers: kube-apiserver (~1.7Gi), Authentik pair (~1.7Gi), VMSingle.
- **Proxmox host `plusha` I/O fragility**: a host-side I/O stall once crashed main-worker-1 (VM 911).
  VM disks use `cache=writeback` (deliberate trade-off). Host `vm.swappiness=30` was set manually and
  is not in IaC.
- **Pending PVC migrations** (manifests already target the new classes; PVCs must be recreated once
  the cluster is up, since storageClass/accessModes are immutable): `vmsingle-vm` (RWX→RWO,
  longhorn-single), `vlsingle-main`, `vtsingle-main`, `harbor-registry`, `data-harbor-trivy-0`.
  Metrics/logs/traces/trivy data is disposable; registry content restores from the Longhorn NFS backup.
- **Stale HelmRelease statuses** (e.g. node-exporter Failed after a one-off timeout) clear with
  `task flux` / `flux reconcile helmrelease ...`.
- **SeaweedFS is kept deliberately** (decision 2026-06-09) for ad-hoc S3 use despite having no
  in-cluster consumers.
