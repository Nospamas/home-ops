---
name: cdi-storageprofile-status
description: CDI could not write StorageProfile status on v1.63.1 (plain Update vs status subresource) — FIXED in v1.66.0; the manual openebs-hostpath patch is no longer needed
metadata:
  node_type: memory
  type: project
  originSessionId: 261740fd-218c-4def-a70e-d2ea353a0444
---

`CDIStorageProfilesIncomplete` fired for `openebs-hostpath` because CDI has no capability entry for the `openebs.io/local` provisioner, so it could not infer `accessModes`/`volumeMode`.

The documented fix — setting `spec.claimPropertySets`, which we do in `kubernetes/apps/virtualization/cdi/app/storageprofile.yaml` — **is correct but does not clear the alert on CDI v1.63.1.**

## Why the spec fix alone doesn't work

The controller does copy spec into status:

```go
if len(storageProfile.Spec.ClaimPropertySets) > 0 {
    claimPropertySets = storageProfile.Spec.ClaimPropertySets
} else {
    claimPropertySets = r.reconcilePropertySets(sc)
}
storageProfile.Status.ClaimPropertySets = claimPropertySets
```

but persists with `r.client.Update(...)`, **not** `Status().Update(...)`. The StorageProfile CRD declares a status subresource (`subresources: {status: {}}`), so the API server silently discards the status half of that write. The controller logs `Updating StorageProfile` and then `Set metric:openebs-hostpath complete:false` on every reconcile, with no error.

The `longhorn-*` profiles have populated status only because it was written by an older CDI before the subresource existed; their `spec` is empty to this day.

## Current state: manual status patch (drift)

Applied 2026-08-05 to clear the alert:

```
kubectl patch storageprofile openebs-hostpath --subresource=status --type=merge \
  -p '{"status":{"claimPropertySets":[{"accessModes":["ReadWriteOnce"],"volumeMode":"Filesystem"}]}}'
```

This sticks precisely *because* CDI cannot write status — nothing reverts it. But it is **not in git**, so it is lost if the StorageProfile is deleted and recreated (CDI recreates it per StorageClass), and it will not survive a cluster rebuild.

The in-repo `spec` is still worth keeping: it is the correct declaration, it is what CDI consumes at DataVolume-creation time, and it starts driving status by itself once CDI fixes the `Update`/`Status().Update()` bug. If the alert returns for `openebs-hostpath`, re-run the patch above rather than assuming the spec is wrong.

## RESOLVED on CDI v1.66.0 (2026-08-29)

The bug predicted at the end of this note is fixed. Proof: `storageprofile-longhorn.yaml` was
added to git with **`spec.claimPropertySets` only** and never status-patched, and CDI populated
`status.claimPropertySets` from it by itself — RWX/Filesystem, RWO/Block, RWO/Filesystem all
mirrored into status, and `kubevirt_cdi_storageprofile_info` flipped to
`degraded=false rwx=true` for `longhorn`.

Consequences:

- **The manual `openebs-hostpath` status patch is no longer load-bearing.** CDI now maintains
  status from spec, so the git `spec` is sufficient and the drift described above is closed.
  No need to re-run the patch if the profile is recreated.
- Declaring `spec.claimPropertySets` is now a complete fix for a degraded profile, not a
  partial one.

Note the remaining `longhorn-*` profiles (fast, single, single-ssd, static, ultra-fast) still
report `degraded=true rwx=false` because they have no `spec` and CDI only ever infers RWO for
`driver.longhorn.io`. That is harmless today — `CDIDefaultStorageClassDegraded` only checks the
default and virt-default classes — but the same one-file fix applies if a specific one matters.

