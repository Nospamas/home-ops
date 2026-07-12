---
name: longhorn-eviction-tickets
description: Longhorn attachment tickets (eviction/clone) pin volumes to old nodes and cause multi-attach errors on pod reschedule
metadata:
  type: project
---

## Symptom

Pods stuck `ContainerCreating` with:

> `Multi-Attach error ... the volume is currently attached to different node <old-node>`

...even though the **old pod is already gone**. Any rollout that changes the pod template (e.g. a chart upgrade) reschedules pods to a new node and triggers this.

## Cause: attachment tickets outlive the pod

`volumeattachments.longhorn.io/<pvc>` holds *multiple* `spec.attachmentTickets`. The CSI ticket correctly targets the new node, but another ticket can pin the volume to the old one:

- `volume-eviction-controller` — present while any replica has eviction pending.
- `volume-clone-controller` — present while a clone (e.g. a Volsync source clone) is unfinished. Ticket id embeds the **target** volume: `volume-clone-controller-<target-pvc>`.

Longhorn attaches where the highest-priority ticket points, so the CSI attach loses and the pod never starts. Inspect with:

```sh
kubectl get volumeattachments.longhorn.io -n storage <pvc> -o json \
  | jq '.spec.attachmentTickets'
```

## Eviction flags live in two places

Clearing `evictionRequested` on the **disk** (`nodes.longhorn.io` → `spec.disks.<disk>`) does **not** clear it on the **replicas**. Both must be cleared or the eviction ticket persists:

```sh
kubectl patch nodes.longhorn.io -n storage <node> --type merge \
  -p '{"spec":{"disks":{"<disk>":{"evictionRequested":false}}}}'
kubectl patch replicas.longhorn.io -n storage <replica> --type merge \
  -p '{"spec":{"evictionRequested":false}}'
```

Note `{"finalizers":[]}` is a no-op in a merge patch — use `{"finalizers":null}`.

## A dead disk wedges deletion permanently

If a disk dies (`input/output error`), replica teardown retries forever:

> `failed to remove host directory /var/mnt/host-ssd/replicas/...: input/output error`

The volume never leaves `deleting`, so its **clone ticket on the source volume is never released** — that blocks an unrelated app's pod from attaching. Longhorn cannot resolve this itself; the only exit is dropping the `longhorn.io` finalizer on the stranded replicas (safe only for volumes already in `deleting`).

Stale replica records on a dead disk do **not** make a volume unhealthy — it stays `healthy` off its surviving replicas. Check `robustness` before assuming data loss.

## Volsync snapshots can outlive their backing data

A `VolumeSnapshot` still reports `readyToUse=true` after its backing `snapshots.longhorn.io` is gone (e.g. it lived on the failed disk). Volsync then clones from it forever:

> `failed to verify data source: snapshot.longhorn.io "snapshot-..." not found`

Recovery (extends the cascade in [[volsync-behaviour]]):

1. **Scale the Volsync controller to 0** — otherwise it recreates the PVC instantly, and the new PVC re-applies `volumesnapshot-as-source-protection` to the terminating snapshot, deadlocking it.
2. Delete mover pod → Job → clone PVC → VolumeSnapshot.
3. **Restart `snapshot-controller`** — its informer cache goes stale and it keeps logging `is being used to restore a PVC` for a PVC that no longer exists, holding the finalizer.
4. Scale Volsync back to 1; it takes a fresh snapshot from the live (healthy) PVC.

## Relationship to other notes

See [[longhorn-drain]] for drain policy and [[volsync-behaviour]] for mover-pod behaviour. Disks are declared in `talos/talconfig.yaml` and applied via the `node.longhorn.io/default-disks-config` annotation (`createDefaultDiskLabeledNodes: true`) — but that annotation only takes effect at **first registration**, so `allowScheduling`/`evictionRequested` changes made in the Longhorn UI are **not** reflected in the repo and won't be reverted by Flux.
