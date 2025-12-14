#!/bin/bash
set -euo pipefail

# Configuration
THRESHOLD_SECONDS=900  # 15 minutes

# Get current timestamp in seconds since epoch
current_timestamp=$(date +%s)

# Find all completed volsync-src jobs across all namespaces
while IFS= read -r job_info; do
    # Skip empty lines
    if [ -z "$job_info" ]; then
        continue
    fi

    namespace=$(echo "$job_info" | jq -r '.namespace')
    job_name=$(echo "$job_info" | jq -r '.name')
    completion_time=$(echo "$job_info" | jq -r '.completionTime')

    # Skip if no completion time (still running)
    if [ "$completion_time" = "null" ]; then
        continue
    fi

    # Convert completion time to seconds since epoch
    completion_timestamp=$(date -d "$completion_time" +%s)

    # Calculate age in seconds
    job_age=$((current_timestamp - completion_timestamp))

    # If job is older than threshold, delete it
    if [ "$job_age" -gt "$THRESHOLD_SECONDS" ]; then
        echo "Deleting $namespace/$job_name (age: ${job_age}s)"
        kubectl delete job "$job_name" -n "$namespace" || true
    fi
done < <(kubectl get jobs --all-namespaces -o json | jq -c '.items[] | select(.metadata.name | startswith("volsync-src-")) | select(.status.completionTime != null) | {namespace: .metadata.namespace, name: .metadata.name, completionTime: .status.completionTime}')

echo "Cleanup completed"
