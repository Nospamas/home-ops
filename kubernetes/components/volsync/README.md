All Volsync substitutions:

APP: (required) name of the pvc for which this will be named
VOLSYNC_ACCESSMODES: (default=ReadWriteOnce)
VOLSYNC_CAPACITY: (default=5Gi)
VOLSYNC_STORAGECLASS: (default=longhorn-fast)

VOLSYNC_CACHE_ACCESSMODES: (default=5gi)
VOLSYNC_CACHE_CAPACITY: (default=5gi)
VOLSYNC_CACHE_SNAPSHOTCLASS: (default=openebs-hostpath)

VOLSYNC_PUID: (default=4012)
VOLSYNC_PGID: (default=4014)

VOLSYNC_SNAPSHOTCLASS: (default=longhorn)

VOLSYNC_SCHEDULE: (default='0 * * * *') Every hour
VOLSYNC_SNAP_ACCESSMODES: (default=ReadWriteOnce)
VOLSYNC_CACHE_ACCESSMODES: (default=ReadWriteOnce)
VOLSYNC_HOURLY: (default=24) Hourlies for one day
VOLSYNC_DAILY: (default=7) Dailies for one week