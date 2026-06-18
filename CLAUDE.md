# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-cluster Kubernetes homelab managed via GitOps. Talos Linux VMs on Proxmox (`plusha`),
provisioned by Terraform, with Flux CD reconciling all in-cluster state from this repo. The active
cluster is `main`. There is no application source code here — everything is infrastructure manifests,
Helm releases, and Terraform.

**`ARCHITECTURE.md` is the authoritative reference** for component versions, IPs, secret paths, Vault
layout, and operational notes. Read it before reasoning about how pieces connect — it is kept current
and far more detailed than this file. Keep it updated when you make structural changes.

## Commands

This repo has no build or test step; "running" means applying Terraform or reconciling Flux.

```
task flux                    # reconcile the full Flux chain (source → flux-system → tenant → controllers → configs)
task tfplan                  # terraform plan across 0-infra, 1-vault, 2-authentik
task new-cluster             # interactive scaffold of a new CAPI-managed Talos cluster (assets/scripts/new-cluster.sh)
task add-kubeconfig CLUSTER=<name>   # add OIDC kubeconfig context for a cluster
task add-sops NAMESPACE=<ns>         # copy sops-gpg secret into a namespace
```

- Terraform stages are ordered and run per-directory: `terraform -chdir=terraform/0-infra plan|apply`
  (then `1-vault`, `2-authentik`, `3-harbor`). `0-infra` creates VMs + Talos + Cilium + bootstraps Flux.
- Reconcile a single resource: `flux reconcile helmrelease <name> -n <ns>` (clears stale Failed statuses).
- Lint is `super-linter` via GitHub Actions, `workflow_dispatch` only (no push-triggered CI).

## How GitOps is wired (the core mental model)

Flux bootstraps from `terraform/0-infra` and syncs `clusters/main/`. The Kustomization chain
(`clusters/main/flux-configs/config-sync.yaml`) is layered and ordered by `dependsOn`:

```
flux-system → main-tenant (infra/tenant) → main-controllers (clusters/main-controllers) → main-configs (clusters/main-configs)
```

- **`infra/`** is the shared/reusable layer (`tenant`, `controllers`, `configs`, `critical`). It is
  cluster-agnostic and parameterized by Flux `postBuild.substitute` variables.
- **`clusters/main-controllers`** and **`clusters/main-configs`** are the main-cluster overlays. They
  pull in the shared layer via `unified-controllers/` → `infra/controllers` and
  `unified-configs/` → `infra/configs`. Put cluster-specific apps directly in these dirs; put anything
  reusable across clusters in `infra/`.

### Variable substitution — two distinct systems, do not mix
- **Flux** (`postBuild.substitute`) uses `${CLUSTER_NAME}`, `${DNS_NAME}`, `${CILIUM_CLUSTER_NAME}`,
  `${CILIUM_CLUSTER_ID}`, `${CILIUM_CLUSTERMESH_ENDPOINT}`. Defined in `config-sync.yaml` per Kustomization.
  Any new `${VAR}` referenced in a manifest must be added to the relevant Kustomization's `substitute` block.
- **Terraform** (`templatefile`) uses `${cluster_name}`, `${cluster_id}`, `${clustermesh_endpoint}` in
  `terraform/0-infra/talos-cluster-module/cilium-values.yaml`. Same concepts, lowercase — keep them in sync.

### Conventions
- Each Helm-based controller dir follows `repository.yaml` (Helm/OCI repo) + `release.yaml` (HelmRelease),
  wired through a local `kustomization.yaml`. Follow this layout when adding a component.
- **Flux always bootstraps from branch `main`.** The cluster has previously become stuck on a feature
  branch — never point the GitRepository or Terraform `branch` var at anything else.
- `prune: true` on controllers/configs but `prune: false` on tenant — deleting a resource from those
  dirs deletes it from the cluster.

## Secrets

Three mechanisms, in order of preference:
- **SOPS** (PGP, key fingerprint in `.sops.yaml`) for secrets committed to git — only `data`/`stringData`
  fields are encrypted. Flux decrypts via the `sops-gpg` secret. New namespaces needing SOPS secrets must
  receive the key (`task add-sops`).
- **ESO + Vault** for runtime secrets. Default `ClusterSecretStore vault-general` (Vault mount `general`,
  AppRole auth). App-specific secrets use namespace `SecretStore`s with Vault Kubernetes auth and per-app
  reader roles. Vault paths and which secret each one feeds are tabulated in `ARCHITECTURE.md`.
- Vault itself auto-unseals via Yandex Cloud KMS; its config lives in `terraform/1-vault`.

## Adding a new cluster

`task new-cluster` scaffolds CAPI objects under `clusters/main-configs/<name>-cluster/` plus
`<name>-tenant/`, `<name>/`, `<name>-configs/`. Then `terraform apply` in `0-infra` for VMs/DNS, commit +
push so Flux applies the CAPI manifests, then `task add-kubeconfig`. CAPI Proxmox manifests are on
CAPMOX v0.8 / v1alpha2 (see the "CAPI Operator" section of `ARCHITECTURE.md` for the exact apiVersions
and required Proxmox token ACLs). ClusterMesh is currently disabled (only `main` exists); re-enabling
steps are documented in `ARCHITECTURE.md`.

## Things that bite

- **Memory, not CPU, is the cluster bottleneck.** Be conservative with new requests/limits.
- **The Proxmox host `plusha` disk subsystem is fragile** — an I/O stall has crashed a worker. Some
  mitigations (`vm.swappiness`, manual host tuning) are **not** in IaC and must be reapplied after a host
  reinstall; these are flagged in `ARCHITECTURE.md`.
- `_old-projects/` is dead reference material (k3s, ArgoCD, Crossplane, etc.) — not part of the live
  system. Don't treat it as current.
- The README's tech list is aspirational/historical and partly stale (mentions GitLab, ArgoCD, k3s which
  are gone). Trust `ARCHITECTURE.md` over the README.
