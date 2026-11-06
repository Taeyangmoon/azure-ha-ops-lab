#!/usr/bin/env bash
# Module 3: generate CPU load on every instance (start) or remove it (stop).
# Uses 'az vmss run-command', so no SSH or inbound port is needed.
# Usage: scripts/stress.sh start [seconds=900] | stop
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
require_login

ACTION="${1:-}"
DURATION="${2:-900}"

run_on() {
  az vmss run-command invoke -g "$RG" -n "$VMSS" --instance-id "$1" \
    --command-id RunShellScript --scripts "$2" --query "value[0].message" -o tsv >/dev/null
}

IDS="$(az vmss list-instances -g "$RG" -n "$VMSS" --query "[].instanceId" -o tsv)"

case "$ACTION" in
  start)
    msg "모든 인스턴스에 CPU 부하를 ${DURATION}초 동안 겁니다." "Starting CPU load on all instances for ${DURATION}s."
    for id in $IDS; do
      run_on "$id" "systemctl stop lab-stress 2>/dev/null; systemd-run --unit=lab-stress stress --cpu \$(nproc) --timeout $DURATION" &
    done
    wait
    msg "부하 시작됨. 확장/경고까지 5~10분 걸립니다." "Load started. Scale-out and the alert take 5-10 minutes."
    ;;
  stop)
    for id in $IDS; do
      run_on "$id" "systemctl stop lab-stress 2>/dev/null || true" &
    done
    wait
    msg "부하를 중지했습니다." "Load stopped."
    ;;
  *)
    die "사용법: scripts/stress.sh start [초] | stop" "Usage: scripts/stress.sh start [seconds] | stop"
    ;;
esac
