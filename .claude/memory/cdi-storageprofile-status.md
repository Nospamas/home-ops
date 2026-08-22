---
name: cdi-storageprofile-status
description: CDI can't write StorageProfile status (plain Update vs status subresource) — openebs-hostpath needed a manual status patch
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
