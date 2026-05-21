---
name: talos-operations
description: Talos/talhelper operational notes — maintenance mode, LinkAliasConfig CEL syntax
metadata:
  type: project
---

Apply config to a node in maintenance mode:
`talosctl apply-config --insecure --nodes <ip> --file talos/clusterconfig/kubernetes-<node>.yaml`

`LinkAliasConfig` is a separate Talos document (not nested in MachineConfig), added as a patch in `talconfig.yaml`. CEL fields: `link.type` (int, 1=ether), `link.kind` (string, `""` = physical hardware). Direct globs like `eth%d` in `bridge.interfaces` are silently ignored — use `LinkAliasConfig` instead.
