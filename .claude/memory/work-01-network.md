---
name: work-01-network
description: work-01 is a Proxmox VM with a single VirtIO NIC — uses LinkAliasConfig for bridge membership
metadata: 
  node_type: memory
  type: project
  originSessionId: 3f7ae8af-40f0-4f4c-82d8-8dce9d8c0235
---

`work-01` is a Proxmox VM (nocloud mode), unlike ctrl-01/02/03 which are bare metal.

Its bridge (`br0`) uses a `LinkAliasConfig` patch (`talos/patches/worker/link-alias.yaml`) to alias the single physical NIC as `vmnic`, which is then referenced in `bridge.interfaces`. This is robust to NIC renaming across Talos upgrades.

CEL selector: `link.type == 1 && link.kind == ""` (type 1 = ether, empty kind = physical hardware).

**Why:** Direct globs like `eth%d` in `bridge.interfaces` are silently ignored by Talos. The `LinkAliasConfig` + `%d` pattern is only valid in v1.13.0+ and only via the alias indirection, not inline in bridge config.

If the node loses external connectivity after a Talos upgrade, suspect the bridge has no physical member. Reset to maintenance mode, check `talosctl get links` for the NIC name, and re-apply config.
