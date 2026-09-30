# Talos Patching

This directory contains the strategic-merge patches that `topf` layers onto each
node's generated machine config.

<https://postfinance.github.io/topf/main/configuration-model/>

## Patch Directories

`topf` loads patches from these directories, in this order, so a later patch
overrides an earlier one:

- `all/`: applied to every node
- `control-plane/`: applied to the control-plane nodes
- `worker/`: applied to the worker nodes
- `node/${node-hostname}/`: applied only to the node with that hostname

Within each directory, files are applied in **lexicographic order** — hence the
`NN-` prefixes. Roughly: `0x-` cluster-level, `1x-` machine-level, `2x-`
networking documents, `3x-` volume documents.

## File Formats

- `*.yaml` — a plain strategic-merge patch. Never templated, so `${...}` and
  `{{ ... }}` survive untouched.
- `*.yaml.tpl` — rendered through Go templates (plus [sprig](https://masterminds.github.io/sprig/))
  before merging. Context: `.Node.Host`, `.Node.IP`, `.Node.Role`, `.Data.<key>`
  (from `topf.yaml`), `.ClusterName`, and more. The **whole file** is parsed as a
  template, comments included — a literal `{{` in a comment breaks the render.

RFC 6902 JSON patches are not supported. Use `$patch: delete` to remove a field
(`field: null` is silently ignored).

A patch may add whole Talos config documents (`apiVersion: v1alpha1` + `kind:`),
not just `machine:` / `cluster:` keys — that is how `BridgeConfig`,
`Layer2VIPConfig`, `UserVolumeConfig`, `VolumeConfig`, `ExistingVolumeConfig`,
`LinkAliasConfig` and `HostnameConfig` are set here.

## Related

- `../topf.yaml` — cluster, node list, versions, and the Image Factory schematic
  references.
- `../schematics/` — Image Factory schematic definitions. `topf schematic-ids`
  resolves them to IDs offline; those IDs form each node's installer image URL.
- `../secrets.sops.yaml` — the cluster PKI/secrets bundle.
