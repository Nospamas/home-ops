# Talos node logs go through a relay on TrueNAS, outside the cluster

Every node sends its kernel log (`KmsgLogConfig`, TCP 6050) and Talos service
logs (`machine.logging`, TCP 6051) to a single Vector relay running as a
TrueNAS custom app (`offcluster/truenas/talos-log-relay/`). The relay writes a
daily JSON-lines archive on TrueNAS (30 days) and forwards to VictoriaLogs
through the internal `logs.${SECRET_DOMAIN}` route. A 1 GiB disk buffer covers
VictoriaLogs being down.

The problem: ctrl-01 has hard-hung twice. Its `dmesg` only covers the current
boot, so each reset destroyed the evidence. Any receiver inside the cluster can
share fate with the node that hangs. During the 2026-11-14 hang, Prometheus
froze with ctrl-01. VictoriaLogs sits on a Longhorn RWO volume that cannot move
while its node is wedged.

We chose one off-cluster relay over an in-cluster relay plus an off-cluster
copy because of how Talos delivers. Its kernel and service log senders stop
retrying a line once *any* destination accepts it. Two destinations therefore
never guarantee two complete copies, and the in-cluster one would have gaps
exactly when it matters. With one path to a box that doesn't share fate with
any node, nothing is duplicated, and the buffer refills VictoriaLogs after an
outage.

Rejected alternatives:
- **netconsole**: built into the Talos kernel, but the NICs use `r8169`, which
  is a module, and dynamic netconsole is off.
- **pstore**: no usable backend is enabled.
- **Direct to VictoriaLogs**: it only ingests JSON lines over HTTP.

Trade-offs:
- The relay isn't reconciled by Flux. Its config lives here, but changes to it
  are applied by hand in the TrueNAS UI.
- Logs stop flowing if TrueNAS is down; Prometheus scrapes the relay, so
  `TargetDown` fires.
- `KmsgLogConfig` can't tag lines, so the relay maps node IPs to names. A new
  node must be added to that map in `vector.yaml`.
- Talos versions before 1.14 can silently lose up to about 15 minutes of TCP
  log lines if the relay vanishes without closing the connection.
