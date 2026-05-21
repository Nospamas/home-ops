---
name: tuppr-upgrade
description: "Tuppr TalosUpgrade CR behaviour — terminal Failed state, node cordons, health check timeouts"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3f7ae8af-40f0-4f4c-82d8-8dce9d8c0235
---

Tuppr manages node upgrades via `TalosUpgrade` CR in the `system` namespace.

**Terminal Failed state**: When `observedGeneration == generation && phase == Failed`, Tuppr logs "Talos upgrade in terminal state, skipping" and stops reconciling. Fix: any spec change (e.g. adding/modifying a healthCheck) bumps `generation` and restarts the loop.

**Why:** Tuppr hit this when an upgrade job timed out mid-flight; the new pod found the CR in Failed and refused to retry.

**Cordons**: After manual node operations (reset, re-apply config), nodes may remain cordoned. Tuppr only uncordons nodes it processed itself. Check with `kubectl get nodes` and uncordon manually if needed.

**Health check timeouts**: Volsync `ReplicationSource` syncs run hourly and take up to ~10 min for large volumes (plex). Longhorn volume rebuilds after reboot take 5–30 min depending on size. Both block Tuppr's Pending→Running transition. Timeouts set to 20m (Volsync) and 30m (Longhorn).
