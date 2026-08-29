# Memory Index

- [Talos operations](talos-operations.md) — maintenance mode apply, LinkAliasConfig CEL syntax
- [Tuppr upgrade behaviour](tuppr-upgrade.md) — terminal Failed state, cordons, health check timeouts
- [Longhorn drain policy](longhorn-drain.md) — allow-if-replica-is-stopped required for rolling upgrades
- [Longhorn attachment tickets](longhorn-eviction-tickets.md) — eviction/clone tickets pin volumes to old nodes → multi-attach on reschedule; dead-disk teardown deadlocks
- [Volsync behaviour](volsync-behaviour.md) — mover jitter, cascade delete order (PVC→pod), Longhorn nodeID stuck on ctrl-03 during upgrades
- [work-01 network config](work-01-network.md) — Proxmox VM, LinkAliasConfig for bridge NIC
- [proxmox/TrueNAS passthrough](proxmox-truenas-passthrough.md) — TrueNAS is VM 100 with an HBA passed through; never force-import ZFS pools on the host
- [CDI StorageProfile status](cdi-storageprofile-status.md) — status subresource bug FIXED in CDI v1.66.0; spec.claimPropertySets now drives status, manual openebs-hostpath patch no longer needed
- [Media download share layout](media-storage.md) — flat `/downloads` share (no category subfolders), 4015 downloading group, unpackerr specifics
- [KubeVirt cross-version migration](kubevirt-cross-version-migration.md) — host-model CPU breaks launcher-version migration; workloadUpdateMethods empty on purpose; restart VMs via kubectl proxy + PUT
- [VM disk RWX/NFS not sparse](vm-disk-rwx-nfs-not-sparse.md) — RWX Longhorn = NFS share-manager, disk.img can't be sparse, PVC pinned ~94%, fstrim no-op; ~20G stranded past vda3
