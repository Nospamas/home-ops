# Volsync is the per-App PVC backup pattern

App PVCs that need backing up opt into the `volsync` Component, which provisions
the PVC and runs restic-based `ReplicationSource`/`ReplicationDestination` movers
to an object store, tuned per-App via the `VOLSYNC_*` substitution knobs. This is
layered **on top of** Longhorn's in-cluster replication: Longhorn protects against
node/disk loss, Volsync protects against cluster loss and gives point-in-time
restore from off-cluster storage.

We chose a per-App opt-in Component over a cluster-wide backup tool (e.g. Velero)
so each App declares its own capacity, schedule, and storage class next to its
manifests, and restore is a first-class part of the App's lifecycle.

Trade-off: every App that wants backup must wire the Component and supply the
knobs — there is no automatic blanket backup.
