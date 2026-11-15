# talos-log-relay

A Vector relay that runs on TrueNAS (192.168.0.51) as a Custom App. It
receives Talos kernel logs on TCP 6050 and service logs on TCP 6051, then:

- archives them to `/mnt/Storage/talos-logs/archive/<date>/<node>.log`, kept
  for 30 days;
- forwards them to VictoriaLogs, with a 1 GiB disk buffer for when it is down;
- serves its own metrics on `:9598`, scraped as the `talos-log-relay` job.

Why it's off the cluster: [ADR 0006](../../../docs/adr/0006-talos-logs-off-cluster-relay.md).
Flux does **not** manage this app. To change it, edit the files here, then
update the app in TrueNAS by hand.

## Install / update

1. Create the dataset `Storage/talos-logs` with subdirectories `config`,
   `data` and `archive`, all owned by `apps` (568:568).
2. Copy `vector.yaml` into `/mnt/Storage/talos-logs/config/`.
3. Go to Apps → Discover → ⋮ → Install via YAML. Name the app
   `talos-log-relay`, paste `compose.yaml`, and set `VICTORIALOGS_URL` to
   `https://logs.<SECRET_DOMAIN>`.
4. After changing `vector.yaml`, restart the app.

## Backfill VictoriaLogs from the archive

The archive files are already in VictoriaLogs' JSON-lines format. If the disk
buffer overflowed, import a day's files like this:

```sh
cat /mnt/Storage/talos-logs/archive/2026-11-20/*.log | curl -sS --data-binary @- \
  'https://logs.<SECRET_DOMAIN>/insert/jsonline?_stream_fields=node,service&_msg_field=msg&_time_field=talos-time'
```
