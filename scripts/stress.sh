#!/usr/bin/env bash
# Module 3: generate CPU load on every instance (start) or remove it (stop).
# Uses 'az vmss run-command', so no SSH or inbound port is needed.
# Usage: scripts/stress.sh start [seconds=900] | stop
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
ACTION="${1:-}"
DURATION="${2:-900}"

case "$ACTION" in
  start)
    [[ "$DURATION" =~ ^[1-9][0-9]*$ ]] || die "부하 시간은 양의 정수(초)여야 합니다." "Duration must be a positive integer in seconds."
    ;;
  stop) ;;
  *) die "사용법: scripts/stress.sh start [초] | stop" "Usage: scripts/stress.sh start [seconds] | stop" ;;
esac
load_env
require_login

run_on() {
  local output
  if ! output="$(az vmss run-command invoke -g "$RG" -n "$VMSS" --instance-id "$1" \
    --command-id RunShellScript --scripts "set -eu
$2
printf '\nLAB_STRESS_OK\n'" --query "value[].message" -o tsv)"; then
    msg "인스턴스 $1 원격 명령 호출 실패." "Run Command invocation failed on instance $1." >&2
    return 1
  fi
  # Run Command can report provisioning success even when the guest script fails.
  if [[ "$output" != *"LAB_STRESS_OK"* ]]; then
    msg "인스턴스 $1 부하 명령 실패: $output" "CPU load command failed on instance $1: $output" >&2
    return 1
  fi
}

IDS="$(az vmss list-instances -g "$RG" -n "$VMSS" --query "[].instanceId" -o tsv)"
[[ -n "$IDS" ]] || die "VMSS 인스턴스가 없습니다." "No VMSS instances found."

STOP_SCRIPT='state=$(systemctl show lab-stress --property=LoadState --value)
if [ "$state" != "not-found" ]; then
  systemctl stop lab-stress
fi'

case "$ACTION" in
  start)
    msg "모든 인스턴스에 CPU 부하를 ${DURATION}초 동안 겁니다." "Starting CPU load on all instances for ${DURATION}s."
    SCRIPT="$STOP_SCRIPT
systemd-run --collect --unit=lab-stress stress --cpu \$(nproc) --timeout $DURATION
systemctl is-active --quiet lab-stress"
    ;;
  stop)
    SCRIPT="$STOP_SCRIPT"
    ;;
esac

PIDS=()
for id in $IDS; do
  run_on "$id" "$SCRIPT" &
  PIDS+=("$!")
done
FAILED=false
for pid in "${PIDS[@]}"; do
  wait "$pid" || FAILED=true
done
[[ "$FAILED" == false ]] || die "일부 인스턴스 명령이 실패했습니다. 위 오류를 확인하세요." "Commands failed on one or more instances. See the errors above."

if [[ "$ACTION" == start ]]; then
  msg "부하 시작됨. 확장/경고까지 5~10분 걸립니다." "Load started. Scale-out and the alert take 5-10 minutes."
else
  msg "부하를 중지했습니다." "Load stopped."
fi
