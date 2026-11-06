#!/usr/bin/env bash
# Shared helpers. Source this file; do not run it.
# LAB_LANG=ko (default) | en

LAB_LANG="${LAB_LANG:-ko}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  az account show >/dev/null 2>&1 || die "az login --use-device-code 로 먼저 로그인하세요." "Run 'az login --use-device-code' first."
}
