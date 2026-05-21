---
name: longhorn-drain
description: Longhorn drain policy required for rolling node upgrades — allow-if-replica-is-stopped
metadata: 
  node_type: memory
  type: project
  originSessionId: 3f7ae8af-40f0-4f4c-82d8-8dce9d8c0235
---

`nodeDrainPolicy: allow-if-replica-is-stopped` is set in `kubernetes/apps/storage/longhorn/app/helmrelease.yaml`.

**Why:** The default `block-if-contains-last-replica` blocks node drain until Longhorn relocates the last replica, which times out Tuppr upgrade jobs. `allow-if-replica-is-stopped` lets drain complete immediately; the replica stops cleanly and re-syncs after the node reboots.

**How to apply:** Volumes will show `degraded` briefly after reboot while replicas catch up — this is expected and not a problem. Tuppr's Longhorn health check (`timeout: 30m`) waits for all volumes to return to `healthy` or `unknown` before proceeding to the next node.
