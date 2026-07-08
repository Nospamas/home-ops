# Prefer bjw-s app-template, fall back to upstream charts

Self-hosted workloads are deployed with the bjw-s `app-template` Helm chart
(pulled as an OCIRepository, referenced via `chartRef`), which gives one
consistent values schema — `controllers` / `containers` / `service` / `route` /
`persistence` — across the whole cluster. This is a **preference, not a rule**:
operators and infrastructure (cilium, cert-manager, longhorn, cnpg, authentik,
kube-prometheus-stack, envoy-gateway, …) are deployed from their own upstream
charts.

The decision rule: reach for the upstream chart when it is well-structured and
adequately covers our deployment; reach for `app-template` when the upstream
chart is poorly structured, low quality, or a bad fit — or when there is no
chart at all. Roughly half the HelmReleases use each path.

Trade-off: app-template couples us to bjw-s's schema and means translating some
upstream chart features by hand, but it keeps the long tail of simple apps
uniform and cheap to reason about.
