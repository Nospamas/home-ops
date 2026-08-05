# Each site runs its own ntfy and probes the other

Alerting terminates at an ntfy instance **inside this cluster**
(`kubernetes/apps/observability/ntfy`). Both alert producers — gatus, and
Alertmanager via the `ntfy-alertmanager` bridge — publish to it over in-cluster
DNS. The other site (`unraid-ops`, on `tower`) runs its own ntfy the same way.
Neither site ever publishes to the other's; the phone subscribes to both.

The problem this solves is that a monitoring stack hosted on the thing it
monitors goes silent exactly when it matters, and silence is indistinguishable
from health. So each site's gatus additionally probes the other's ntfy and gatus
over the tailnet: if tower dies, home-ops notices and shouts on home-ops's ntfy,
and the reverse. Those cross-site probes carry a deliberately longer failure
threshold than local ones, because the path between sites crosses the open
internet and a transient WAN blip is not the other site dying.

We chose mutual probing over cross-site publishing so that neither site needs a
credential for the other — only the ability to *reach* it. Tailscale supplies
that reachability, via the operator's egress mode rather than a subnet router:
the home network is `192.168.0.0/16`, which contains rb's `192.168.1.0/24`, and
egress mode sidesteps the overlap by using tailnet addresses only.

The governing rule for anything on this path: **the alert path must not traverse
the thing it reports on.** ntfy is published on the tailnet, not through
`envoy-external` and the Cloudflare Tunnel, because a tunnel outage would
otherwise take out both the services and the ability to report on them. The same
test applies to Alertmanager's route to ntfy, which is why the bridge is
addressed by cluster-local DNS.

Trade-off: two ntfy servers to keep alive and two subscriptions on the phone, and
the tailscale operator needs an OAuth client — the one credential here that has
to be created by hand in the Tailscale admin console (scopes: Devices→Core write
and Keys→Auth Keys write, tagged `tag:k8s-operator`, with `tag:k8s-operator` and
`tag:k8s` declared in the tailnet policy's `tagOwners`) before anything on the
tailnet works. Alertmanager's `Watchdog` dead-man's switch is dropped locally
rather than aimed at a third party such as healthchecks.io — tower's probes are
the dead-man's switch.
