---
name: vm-disk-rwx-nfs-not-sparse
description: ubuntu-dev's RWX Longhorn disk lands on the NFS share-manager, so disk.img can never be sparse — PVC sits at ~94% permanently and fstrim is a no-op on the host
metadata:
  node_type: memory
  type: project
---

**`KubePersistentVolumeFillingUp` for `virtualization/ubuntu-dev` cannot be cleared by freeing
space inside the guest.** Understood 2026-08-29 after reclaiming 18G in the guest changed the
PVC metric by exactly zero.

## Why

The disk PVC is **ReadWriteMany + Filesystem** (RWX is required for live migration). Longhorn
serves RWX Filesystem through its **share-manager**, so the launcher mounts it over NFS:

```
10.43.21.117:/pvc-9ae6f9a1-...  74G  69G  4.4G  94%  /run/kubevirt-private/vmi-disks/ubuntu-dev
```

**NFS does not support hole punching.** The domain XML *does* set `discard='unmap'`
(verified via `virsh dumpxml`), and `fstrim` inside the guest genuinely succeeds —
`/: 23.8 GiB trimmed` — but QEMU cannot deallocate blocks on an NFS-backed raw file. `stat`
confirms zero holes: `blocks × 512 == apparent size == 73939288064`, exactly the size of
`/dev/vda`.

So `disk.img` grew as blocks were touched (52.5GB → 73.9GB over 7 days) and has now reached its
ceiling. **It is at maximum and cannot grow further**, which also makes the alert's "expected to
fill up within four days" a meaningless extrapolation of a curve that has already flattened.

## Practical reading

- Guest-side cleanup is still worth doing — the guest filesystem was genuinely at 94% and would
  have run out. It just has no effect on the PVC metric.
- The PVC will read ~94% forever. There is no leak and no risk.
- Options if the alert must go: expand the PVC (`longhorn-fast` has
  `allowVolumeExpansion: true`), or exclude VM-disk PVCs from the rule. Switching the disk to
  `volumeMode: Block` would avoid NFS entirely but means recreating the disk.

## Related: ~20G of stranded capacity in the guest

`/dev/vda` is **68.86 GiB** but the partitions stop at 46.9G — `vda3` ends at sector 102545407
of 144412672, and the VG has `VFree 0`. About **20G is allocated in the image and paid for in
the PVC, but unusable by the guest**. Reclaim with `growpart /dev/vda 3 && pvresize /dev/vda3 &&
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv && resize2fs /dev/ubuntu-vg/ubuntu-lv`
(online-safe on ext4). Not done as of 2026-08-29 — the guest was at 52% after cleanup so it was
elective, and it is partition surgery on the root disk of the VM the agent runs inside.

Note this does **not** change the PVC metric: the blocks are already allocated either way.

## Biggest guest disk consumers found (2026-08-29)

Freed 18G, 94% → 52%: mise old tool versions 11G → 1.3G (141 versions;
`mise prune --tools` is **broken** in 2026.4.11 — dry-run lists them, the real run silently
no-ops, so loop `mise ls --prunable` into `mise uninstall`), `snapd/cache` 6.1G,
`.vscode-server/cli/servers` 5.7G → 1.4G (keep the running one — check `ps`), 12 disabled snap
revisions, journal 991M → 197M, two superseded Claude versions. Left alone: 3.6G of unused
Docker images (all re-pullable ghcr images, 0 containers). See
[[kubevirt-cross-version-migration]].
