#!/usr/bin/env bash
# Dump recent alert traffic without leaving the terminal.
#
# ntfy is only reachable over the tailnet and Alertmanager has no Route at all,
# so both are read through short-lived port-forwards on high ports. ntfy's cache
# is 168h, which bounds how far SINCE can usefully reach back.
set -euo pipefail

SINCE="${1:-24h}"
NTFY_PORT=${NTFY_PORT:-18080}
ALERTMANAGER_PORT=${ALERTMANAGER_PORT:-19093}

pids=()
cleanup() { for pid in "${pids[@]:-}"; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT

forward() {
    kubectl port-forward --namespace observability "svc/$1" "$2:$3" >/dev/null 2>&1 &
    pids+=("$!")
}

forward ntfy "$NTFY_PORT" 80
forward kube-prometheus-stack-alertmanager "$ALERTMANAGER_PORT" 9093

# port-forward reports ready on stdout we have thrown away, so poll the ports.
for _ in $(seq 30); do
    curl -sf "http://127.0.0.1:${NTFY_PORT}/v1/health" >/dev/null 2>&1 &&
        curl -sf "http://127.0.0.1:${ALERTMANAGER_PORT}/-/ready" >/dev/null 2>&1 && break
    sleep 0.5
done

echo "=== Firing now (Alertmanager, excluding silenced/inhibited) ==="
curl -s "http://127.0.0.1:${ALERTMANAGER_PORT}/api/v2/alerts?active=true&silenced=false&inhibited=false" |
    jq -r 'sort_by(.labels.severity, .labels.alertname)[]
        | [ .labels.severity,
            .labels.alertname,
            (.startsAt | sub("\\.[0-9]+";"") | fromdate | strflocaltime("%m-%d %H:%M")),
            (.labels | to_entries
                     | map(select(.key | test("^(namespace|pod|node|instance|name|job_name|device|container)$")))
                     | map("\(.key)=\(.value)") | join(" "))
          ] | @tsv' |
    column -t -s $'\t'

echo
echo "=== ntfy home-ops, last ${SINCE}, by title ==="
notifications=$(curl -s "http://127.0.0.1:${NTFY_PORT}/home-ops/json?poll=1&since=${SINCE}")

# ntfy-alertmanager runs in alert-mode single, so a title is one alert instance:
# collapsing on it turns a flapping endpoint into a single line with a count.
jq -r 'select(.event == "message") | .title' <<<"$notifications" |
    sed -E 's/^\[(FIRING|RESOLVED)\] //' |
    sort | uniq -c | sort -rn |
    awk '{ count = $1; $1 = ""; sub(/^ /, ""); printf "%5d  %s\n", count, $0 }'

echo
echo "=== ntfy home-ops, last ${SINCE}, chronological ==="
jq -r 'select(.event == "message")
    | [ (.time | strflocaltime("%m-%d %H:%M")), .title ] | @tsv' <<<"$notifications" |
    column -t -s $'\t'
