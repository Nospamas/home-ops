This is a Kubernetes Flux GitOps repo. Inspect the cluster via `kubectl`, configure Talos nodes via `talosctl`.

Don't modify the cluster by directly applying — make code changes and reconcile via Flux. The user commits changes; ask them to review before that stage.

Talos node configs live in `talos/` and are compiled with `talhelper` into `talos/clusterconfig/`. `talhelper genconfig` requires the SOPS age key — must be run by the user.

Namespaces: `storage` contains Longhorn and Volsync. Components shared across apps are in `kubernetes/components/`.

Don't use force deletions unless normal deletion has been tried first.

Extended notes on specific systems are in `.claude/memory/` with an index summary at `.claude/memory/MEMORY.md` — load relevant files as needed.

## Where things are documented

- **`CONTEXT.md`** (repo root) — glossary of this repo's coined terms (App, Component, the `IP_*`/`VOLSYNC_*`/etc. substitution vocabulary, `cluster-secrets`, the internal/external Gateways). Read it to understand what a term *means*.
- **`docs/adr/`** — architecture decision records: *why* we chose SOPS+age, app-template, Volsync, and the cluster-secrets substitution pattern. Read before "fixing" something that looks deliberate.
- **`.claude/memory/`** — surprising *runtime behaviour* of specific systems (Talos, Longhorn drain, Volsync movers, tuppr, work-01). A different category from conventions.

## Conventions

**App layout.** Each App lives at `kubernetes/apps/<namespace>/<app>/`:
- `ks.yaml` — the Flux `Kustomization`. Uses YAML anchors `&app`/`&namespace`, sets `path` to the `app/` dir, opts into Components under `spec.components`, declares `dependsOn`, and passes per-App values via `postBuild.substitute` (e.g. `APP`, `VOLSYNC_CAPACITY`).
- `app/kustomization.yaml` — lists the resources (`helmrelease.yaml`, and any `pvc.yaml`, `secret.sops.yaml`, `ocirepository.yaml`).
- `app/helmrelease.yaml` — the workload (see chart selection below).

**Registering an App.** Add the App's `ks.yaml` to the namespace's `kubernetes/apps/<namespace>/kustomization.yaml` `resources:` list. That namespace kustomization pulls in `components/common` (namespace + sops) and `components/repos/cluster-template`.

**YAML-anchor idiom.** Define once, reference everywhere: `&app`/`*app` for the name, `&namespace`/`*namespace`, `&port`/`*port`, `&probes`/`*probes`.

**Chart selection.** Prefer the bjw-s `app-template` chart (OCIRepository + `chartRef`) for self-hosted workloads; use the upstream chart for operators/infra or when app-template is a poor fit. See `docs/adr/0002`.

**Config substitution.** Shared values (`SECRET_DOMAIN`, `CLUSTER_TIMEZONE`, the `IP_*` scheme) come from the `cluster-secrets` Secret (`kubernetes/components/common/sops/cluster-secrets.sops.yaml` — the authoritative key list), injected into every App via a root-level `substituteFrom` patch. Reference them as `${VAR}` in any manifest — no local definition needed. Opt out with the `kustomize.toolkit.fluxcd.io/skip-cluster-secrets` annotation. Per-Component knobs (`VOLSYNC_*`, `CNPG_*`, `DRAGONFLY_*`) are defined inline as `${VAR:=default}` in each `kubernetes/components/<name>/` dir. See `docs/adr/0004`.

**Secrets.** Committed encrypted as `*.sops.yaml` (SOPS + age). See `docs/adr/0001`.

**Networking.** Attach `HTTPRoute`s to the `envoy-internal` Gateway for LAN-only, `envoy-external` for internet-exposed (Cloudflare tunnel). External exposure is always deliberate.

**Backups.** Opt an App's PVC into the `components/volsync` Component and set the `VOLSYNC_*` knobs. See `docs/adr/0003`.

**Validation.** `flux-local` runs in CI (`.github/workflows/flux-local.yaml`) and renders substitutions; `task reconcile` forces Flux to pull changes after they're committed. Tooling is pinned in `.mise.toml`.
