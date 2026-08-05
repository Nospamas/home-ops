# Memory Index

- [Talos operations](talos-operations.md) — maintenance mode apply, LinkAliasConfig CEL syntax
- [Tuppr upgrade behaviour](tuppr-upgrade.md) — terminal Failed state, cordons, health check timeouts
- [Longhorn drain policy](longhorn-drain.md) — allow-if-replica-is-stopped required for rolling upgrades
- [Longhorn attachment tickets](longhorn-eviction-tickets.md) — eviction/clone tickets pin volumes to old nodes → multi-attach on reschedule; dead-disk teardown deadlocks
- [Volsync behaviour](volsync-behaviour.md) — mover jitter, cascade delete order (PVC→pod), Longhorn nodeID stuck on ctrl-03 during upgrades
- [work-01 network config](work-01-network.md) — Proxmox VM, LinkAliasConfig for bridge NIC
- [proxmox/TrueNAS passthrough](proxmox-truenas-passthrough.md) — TrueNAS is VM 100 with an HBA passed through; never force-import ZFS pools on the host
- [CDI StorageProfile status](cdi-storageprofile-status.md) — CDI can't persist status (subresource bug); openebs-hostpath holds a manual status patch, not in git
- [Media download share layout](media-storage.md) — flat `/downloads` share (no category subfolders), 4015 downloading group, unpackerr specifics
