#!/usr/bin/env bash
# Send N requests to the load balancer and count which instance answered.
# Usage: scripts/curl-loop.sh [count=20]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

COUNT="${1:-20}"
[[ "$COUNT" =~ ^[1-9][0-9]*$ ]] || die "요청 횟수는 양의 정수여야 합니다." "Request count must be a positive integer."
for _ in $(seq 1 "$COUNT"); do
  # New connection each time (no keep-alive) so the load balancer can pick a different instance.
  curl -fsS --max-time 3 -H 'Connection: close' "http://$LB_IP/whoami.txt" || echo "FAILED"
  sleep 0.3
done | sort | uniq -c
