This is a Kubernetes Flux GitOps repo. Inspect the cluster via `kubectl`, configure Talos nodes via `talosctl`.

Don't modify the cluster by directly applying — make code changes and reconcile via Flux. The user commits changes; ask them to review before that stage.

Talos node configs live in `talos/` and are compiled with `talhelper` into `talos/clusterconfig/`. `talhelper genconfig` requires the SOPS age key — must be run by the user.

Namespaces: `storage` contains Longhorn and Volsync. Components shared across apps are in `kubernetes/components/`.

Don't use force deletions unless normal deletion has been tried first.

Extended notes on specific systems are in `.claude/memory/` with an index summary at `.claude/memory/MEMORY.md` — load relevant files as needed.
