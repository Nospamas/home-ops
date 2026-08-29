---
name: kubevirt-cross-version-migration
description: VMs cannot live-migrate across virt-launcher versions here (host-model CPU) — KubeVirt minor upgrades need a VM restart, so workloadUpdateMethods is deliberately empty
metadata:
  node_type: memory
  type: project
---

**A KubeVirt minor upgrade cannot move a running VM to the new virt-launcher in this cluster.**
Established across two boundaries during the staged v1.6.1 → v1.9.0 upgrade (2026-08-28/29).

| Boundary | Failure |
|---|---|
| v1.6.6 → v1.7.4 | `qemu-kvm: Features 0x1c0010130afffaf unsupported. Allowed features: 0x10179bfffef` (virtio) |
| v1.7.4 → v1.8.4 | `guest CPU doesn't match specification: extra features: ht` (CPU) |

Both are host/guest capability negotiation against a changed libvirt/QEMU. Each failed
deterministically — four attempts in ~3 minutes on the first, identical every time. The source
transfers most of RAM (~938MB observed) and then the **target** QEMU rejects the incoming
definition and closes its monitor; the source reports
`virError(Code=1, Domain=7, 'internal error: client socket is closed')`.

## Root cause

`cpu.model` resolves to **`host-model`**, which libvirt resolves against the *source host at VM
start time*. A launcher upgrade swaps libvirt/QEMU underneath the running domain and the
resolved definition stops validating on the target.

`host-model` is **not** set in `ubuntu-dev/app/vm.yaml` — that file sets only `cpu.cores: 4`.
It is KubeVirt's default. Ruled out as causes: node hardware (ctrl-01/02/03 all report
`host-model-cpu.node.kubevirt.io/EPYC-Milan` with identical 117 `cpu-feature.*` labels) and
storage (the disk is RWX, `StorageLiveMigratable=True` throughout).

## What this means operationally

- `workloadUpdateStrategy.workloadUpdateMethods: []` in `kubevirt/instance/cr.yaml` is
  **deliberate**, not a leftover. Re-enabling `LiveMigrate` guarantees a failing retry storm at
  the next minor upgrade — a new target pod roughly every 40s, each dying the same way.
- **Same-version migration works fine.** Stage 0 migrated ctrl-01 → ctrl-03 cleanly with both
  launchers on v1.6.6, boot id unchanged. So node drains are unaffected — eviction is governed
  by the VM's `evictionStrategy: LiveMigrateIfPossible`, not by `workloadUpdateStrategy`.
- After a KubeVirt upgrade the VM keeps running happily on its **old** launcher (KubeVirt
  supports this). Move it forward with a restart when convenient.

## Restarting a VM without virtctl

`virtctl` is not in `.mise.toml`. `kubectl create --raw` does **not** work — the subresource is
PUT-only and returns `MethodNotAllowed` for POST. What works:

```
kubectl proxy --port=8001 &
curl -X PUT -H 'Content-Type: application/json' -d '{}' \
  http://127.0.0.1:8001/apis/subresources.kubevirt.io/v1/namespaces/virtualization/virtualmachines/ubuntu-dev/restart
```
Returns HTTP 202.

## The durable fix, not taken

Pin an explicit CPU model (`spec.template.spec.domain.cpu.model`, or cluster-wide
`KubeVirt.spec.configuration.cpuModel`). `EPYC-Milan` suits ctrl-01/02/03 but **excludes
work-01**, which reports plain `EPYC` with only 86 cpu-features — it would stop being a
migration target. Requires a VM restart to take effect. Deliberately declined 2026-08-29 in
favour of accepting a restart per upgrade. See [[vm-disk-rwx-nfs-not-sparse]].
