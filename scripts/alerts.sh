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
                     | map(select(.key | test("^(namespace|pod|node|instance|name|job_name|device|container|obj_namespace|obj_name)$")))
                     | map("\(.key)=\(.value)") | join(" "))
          ] | @tsv' |
    column -t -s $'\t'

echo
echo "=== ntfy home-ops, last ${SINCE}, by alert ==="
notifications=$(curl -s "http://127.0.0.1:${NTFY_PORT}/home-ops/json?poll=1&since=${SINCE}")

# The title only names the scrape job, so pull the subject from the body labels.
lines=$(jq -r 'select(.event == "message")
    | (.message | [scan("(?m)^- ([a-z_]+) = (.+)$")] | map({(.[0]): .[1]}) | add // {}) as $l
    | (if $l.obj_name then "\($l.obj_namespace)/\($l.obj_name)"
       elif $l.pod then "\($l.namespace)/\($l.pod)" + (if $l.container then " (\($l.container))" else "" end)
       else ($l.namespace // "") end) as $subject
    | [ (.time | strflocaltime("%m-%d %H:%M")),
        (.title | capture("^\\[(?<s>[A-Z]+)\\]").s // ""),
        ($l.alertname // .title),
        $subject ] | @tsv' <<<"$notifications")

# alert-mode single: one line per alert+subject, so flapping collapses to a count.
cut -f3,4 <<<"$lines" | sort | uniq -c | sort -rn |
    awk -F'\t' '{ printf "%s  %s\n", $1, $2 }'

echo
echo "=== ntfy home-ops, last ${SINCE}, chronological ==="
column -t -s $'\t' <<<"$lines"
