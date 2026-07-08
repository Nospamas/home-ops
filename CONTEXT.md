# Home-Ops Cluster

The ubiquitous language of this Kubernetes Flux GitOps repo. This is a glossary
of terms **this repo coins or gives a specific local meaning** — not a Flux or
Kubernetes tutorial. The *mechanism* behind these terms lives in `CLAUDE.md`;
the *why* behind big choices lives in `docs/adr/`.

## Units

**App**:
A single deployed workload, owning the directory `kubernetes/apps/<namespace>/<app>/`.
It is the atom of this repo: one `ks.yaml` (its Flux Kustomization) plus an
`app/` dir holding the manifests. The app's name is carried everywhere by the
`&app` YAML anchor and the `APP` substitution variable.
_Avoid_: service, deployment, release (those are narrower Kubernetes objects the App contains).

**Component**:
A reusable capability bundle under `kubernetes/components/` that an App opts into
from its `ks.yaml` (e.g. `volsync`, `ext-auth`, `cnpg`, `dragonfly`, `common`).
A Component is parameterised by substitution variables the App supplies.
_Avoid_: module, mixin, plugin.

## Substitution vocabulary

Variables resolved into manifests at build time. Two families: cluster-wide
(from `cluster-secrets`) and per-App (from a Kustomization's `postBuild.substitute`).

**`APP`**:
The canonical App name. Mirrors the `&app` anchor and drives hostnames, claim
names, and Component wiring. Set per-App in `postBuild.substitute`.

**Cluster-wide variables** (`SECRET_DOMAIN`, `CLUSTER_TIMEZONE`, the `IP_*`
address scheme, …):
Values injected into every App from the `cluster-secrets` Secret. That file is
the authoritative list — read
`kubernetes/components/common/sops/cluster-secrets.sops.yaml` for the full set of
keys. The `IP_*` naming scheme within it: `IP_GATEWAY` (network gateway),
`IP_DNS_PRIMARY`/`IP_DNS_SECONDARY` (resolvers), `IP_SVC_<name>` (a service's
LoadBalancer IP), `IP_IOT_<name>` (an address on the IoT network).

**Component knobs** (`VOLSYNC_*`, `CNPG_*`, `DRAGONFLY_*`):
The dials an App sets in its `postBuild.substitute` to configure a Component.
Each Component's manifests are the authoritative, self-documenting list: the
knobs appear inline as `${VAR:=default}`, so the default is right there. Read the
Component directory for the full set, e.g.:
- `kubernetes/components/volsync/` — `VOLSYNC_CAPACITY`, `VOLSYNC_SCHEDULE`, `VOLSYNC_STORAGECLASS`, …
- `kubernetes/components/cnpg/` — `CNPG_VERSION`, `CNPG_SIZE`, `CNPG_STORAGECLASS`, …
- `kubernetes/components/dragonfly/` — `DRAGONFLY_LIMITS_MEMORY`, `DRAGONFLY_ARGS_THREADS`, …

**`cluster-secrets`**:
The SOPS-encrypted Secret whose keys are substituted into every App's manifests
by default. Defined at `kubernetes/components/common/sops/cluster-secrets.sops.yaml`.

**`skip-cluster-secrets`**:
The annotation an App's Kustomization sets to opt **out** of `cluster-secrets`
injection.

## Trust zones

**envoy-internal**:
The Gateway for LAN-only routes. An App attaching here is reachable only from the
internal network.
_Avoid_: private, local (ambiguous).

**envoy-external**:
The Gateway for internet-exposed routes (published via the Cloudflare tunnel). An
App attaches here deliberately — external exposure is never the default.
_Avoid_: public, ingress.
