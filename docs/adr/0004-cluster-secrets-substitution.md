# Cluster-wide config via postBuild substitution of cluster-secrets

The root `cluster-apps` Kustomization patches **every** App's Flux Kustomization
to `substituteFrom` the `cluster-secrets` Secret, so shared values
(`SECRET_DOMAIN`, `CLUSTER_TIMEZONE`, the `IP_*` address scheme) are available as
`${VAR}` in any manifest without per-App wiring. An App opts out by setting the
`kustomize.toolkit.fluxcd.io/skip-cluster-secrets` annotation. Per-App values are
supplied separately through each Kustomization's own `postBuild.substitute`
(e.g. `APP`, the `VOLSYNC_*` knobs).

This is the repo's central piece of "magic" and the most surprising thing for a
newcomer: a manifest referencing `${SECRET_DOMAIN}` has no local definition of
it. We accept that indirection to keep one authoritative place for shared
addresses and domains, and to make Components parameterisable by substitution.

Trade-off: values resolve at Flux build time, so `${VAR}` references can't be
validated by reading a single file — you must know the global scheme (see
`CONTEXT.md`). The `flux-local` tooling renders substitutions for validation.
