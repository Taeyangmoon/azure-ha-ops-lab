#!/usr/bin/env bash
# Shared helpers. Source this file; do not run it.
# LAB_LANG=ko (default) | en

LAB_LANG="${LAB_LANG:-ko}"
ROOT_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.lab.env"

# msg "<korean>" "<english>"
msg() {
  if [[ "$LAB_LANG" == "en" ]]; then echo "$2"; else echo "$1"; fi
}

die() {
  msg "오류: $1" "ERROR: $2" >&2
  exit 1
}

load_env() {
  [[ -f "$ENV_FILE" ]] || die ".lab.env 가 없습니다. 먼저 scripts/deploy.sh 를 실행하세요." ".lab.env not found. Run scripts/deploy.sh first."
  # shellcheck disable=SC1090
  source "$ENV_FILE"
}

require_login() {
  local current_subscription
  current_subscription="$(az account show --query id -o tsv)" || die "az login --use-device-code 로 먼저 로그인하세요." "Run 'az login --use-device-code' first."
  if [[ -n "${SUBSCRIPTION_ID:-}" && "$current_subscription" != "$SUBSCRIPTION_ID" ]]; then
    die "랩을 배포한 구독과 다릅니다. az account set --subscription '$SUBSCRIPTION_ID' 로 선택하세요." \
        "Wrong subscription. Select the lab subscription with: az account set --subscription '$SUBSCRIPTION_ID'"
  fi
}
