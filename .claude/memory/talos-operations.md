---
name: talos-operations
description: Talos/topf operational notes — maintenance mode, LinkAliasConfig CEL syntax
metadata:
  type: project
---

Apply config to a node in maintenance mode: `topf apply --nodes-filter '<hostname>'` (topf detects maintenance mode and skips post-apply health checks). To go through `talosctl` instead, render first with `task talos:generate-config`, then `talosctl apply-config --insecure --nodes <ip> --file talos/output/<hostname>.yaml`.

`LinkAliasConfig` is a separate Talos document (not nested in MachineConfig), added as a patch file — `talos/patches/node/work-01/01-link-alias.yaml`. CEL fields: `link.type` (int, 1=ether), `link.kind` (string, `""` = physical hardware). Direct globs like `eth%d` in `bridge.interfaces` are silently ignored — use `LinkAliasConfig` instead.
