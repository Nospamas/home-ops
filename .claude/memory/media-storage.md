# Media download share layout

The download share is `truenas.server.internal:/mnt/Storage/downloading`, mounted at
`/downloads` by qbittorrent (rw), radarr/sonarr (ro), and unpackerr (rw).

**It is flat.** qbittorrent drops every completed download directly into the share root —
there are no `tv/`, `movies/`, `anime/` category subfolders. So any arr-adjacent tool
(e.g. unpackerr) that monitors download paths points at the bare `/downloads`, not
`/downloads/<category>`. If qbittorrent categories with subfolders are ever added, those
paths would need to narrow.

**Ownership / groups** (visible in the media helmreleases): files are owned `4011:4015`,
mode `drwxrwx--x`. `4015` is the *downloading* group; membership (fsGroup/supplementalGroups)
is what grants access to the share. Per-app UIDs: qbittorrent 4011, radarr 4020, sonarr 4021.
Media library shares are separate NFS exports under `/mnt/Storage/{movies,tv}`.

unpackerr runs as `4011:4015` so its extractions match qbittorrent's ownership. It has no
web UI (metrics-only ServiceMonitor, no HTTPRoute) and pulls the arr API keys cross-app via
`secretKeyRef` to the existing `radarr-secret`/`sonarr-secret` in the same namespace, so it
needs no SOPS secret of its own.
