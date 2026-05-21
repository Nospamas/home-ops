---
name: volsync-behaviour
description: Volsync mover pod behaviour, stuck jobs, cascade delete order, ctrl-03 engine issue
metadata:
  type: project
---

## Mover pod jitter

Volsync mover pods have an init container (`jitter`) that sleeps 0–30 seconds before starting. A pod sitting at `Init:0/1` for under 30s is normal — not stuck.

## Cascade delete order for stuck jobs

When a mover pod is stuck (e.g. volume can't attach), the correct deletion order is:

1. Delete the **PVC** first (puts it in `Terminating`, blocked by pod)
2. Delete the **pod** (releases the PVC hold, PVC finalizes and deletes)
3. Volsync reconciles and recreates the Job/pod fresh

Deleting pod alone respawns it immediately; deleting Job alone also respawns. The PVC must be deleted first to break the cycle cleanly.

**Why:** Volsync watches the ReplicationSource and immediately recreates jobs when they disappear. Removing the PVC first ensures the new pod gets a fresh Longhorn volume unaffected by stale node assignments.

## Longhorn engines stuck on cordoned ctrl-03

When Tuppr cordons ctrl-03 for upgrade and Volsync runs its hourly sync, new src PVCs can end up with `spec.nodeID: ctrl-03` in the Longhorn Volume object — even if the mover pod is scheduled on a different node. The engine is then created on ctrl-03 (stopped, because the instance manager pod can't schedule there), and the volume stays `attaching` indefinitely.

**Fix:** `kubectl patch volume.longhorn.io -n storage <pvc-name> --type merge -p '{"spec":{"nodeID":"<correct-node>"}}'` — once the nodeID matches the node where the VolumeAttachment was requested, Longhorn creates the engine there and the volume attaches.

**Why:** The nodeID gets set on the first VolumeAttachment request. If the pod was briefly queued on ctrl-03 before the cordon fully took effect, ctrl-03 becomes the nodeID. When the pod reschedules to another node, Longhorn's volume object isn't updated automatically.

## No native pause for ReplicationSources

Volsync has no `spec.paused` field. To stop a running sync you must either scale down the Volsync controller or delete the Job — but deleting the Job causes immediate respawn. The only reliable "stop" is scaling down the controller or deleting both the Job and the source PVC in that order (PVC → pod), then waiting for the next schedule.

## Relationship to Tuppr upgrades

See [[tuppr-upgrade]]. Volsync `ReplicationSource` `Synchronizing=True` blocks Tuppr's health check. If syncs get stuck during a ctrl-03 upgrade cycle, use the cascade delete pattern above (PVC then pod) and patch any Longhorn volumes with `spec.nodeID: ctrl-03` to the correct node.
