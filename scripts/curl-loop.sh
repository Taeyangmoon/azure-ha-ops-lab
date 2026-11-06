#!/usr/bin/env bash
# Send N requests to the load balancer and count which instance answered.
# Usage: scripts/curl-loop.sh [count=20]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

COUNT="${1:-20}"
for _ in $(seq 1 "$COUNT"); do
  # New connection each time (no keep-alive) so the load balancer can pick a different instance.
  curl -s --max-time 3 -H 'Connection: close' "http://$LB_IP/whoami.txt" || echo "FAILED"
  sleep 0.3
done | sort | uniq -c
