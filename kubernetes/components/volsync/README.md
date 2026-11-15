All Volsync substitutions:

APP: (required) name of the pvc for which this will be named
VOLSYNC_ACCESSMODES: (default=ReadWriteOnce)
VOLSYNC_CAPACITY: (default=5Gi)
VOLSYNC_STORAGECLASS: (default=longhorn-fast)

VOLSYNC_CACHE_ACCESSMODES: (default=ReadWriteOnce)
VOLSYNC_CACHE_CAPACITY: (default=10Gi) all Apps share one kopia repo, so the (unbounded) index cache scales with the whole repo, not the App. The two limits below do not cover it — leave headroom.
VOLSYNC_CACHE_STORAGECLASS: (default=longhorn-ultra-fast)
VOLSYNC_CACHE_METADATA_MB: (default=2560) kopia metadata cache limit, ~25% of a 10Gi cache
VOLSYNC_CACHE_CONTENT_MB: (default=768) kopia content cache limit, ~7% of a 10Gi cache

VOLSYNC_PUID: (default=4012)
VOLSYNC_PGID: (default=4014)

VOLSYNC_SNAPSHOTCLASS: (default=longhorn)

VOLSYNC_SCHEDULE: (default='0 * * * *') Every hour
VOLSYNC_SNAP_ACCESSMODES: (default=ReadWriteOnce)
VOLSYNC_CACHE_ACCESSMODES: (default=ReadWriteOnce)
VOLSYNC_HOURLY: (default=24) Hourlies for one day
VOLSYNC_DAILY: (default=7) Dailies for one week