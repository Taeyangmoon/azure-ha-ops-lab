#!/usr/bin/env bash
# Cleanup: delete everything created by this lab (one resource group).
# Usage: scripts/cleanup.sh [-y] [--wait]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

YES=false
WAIT=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=true ;;
    --wait) WAIT=true ;;
    *) die "알 수 없는 옵션: $arg" "Unknown option: $arg" ;;
  esac
done

if [[ -f "$ENV_FILE" ]]; then source "$ENV_FILE"; fi
RG="${RG:-${RESOURCE_GROUP:-}}"
[[ -n "$RG" ]] || die ".lab.env 가 없습니다. 삭제할 리소스 그룹을 RESOURCE_GROUP 으로 명시하세요." \
    ".lab.env not found. Explicitly set RESOURCE_GROUP to the group you want to delete."

require_login
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"

EXISTS="$(az group exists -n "$RG")"
[[ "$EXISTS" == true || "$EXISTS" == false ]] || die "리소스 그룹 존재 여부를 확인하지 못했습니다." "Could not determine whether the resource group exists."
BUDGET_IDS="$(az rest --url "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.Consumption/budgets?api-version=2024-08-01" --query "value[].id" -o tsv)"
if [[ "$EXISTS" == true || -n "$BUDGET_IDS" ]]; then
  if [[ "$YES" != true ]]; then
    msg "리소스 그룹 '$RG' 의 예산과 모든 리소스를 삭제합니다." "This deletes the budgets and all resources in resource group '$RG'."
    read -r -p "$(msg "계속하려면 리소스 그룹 이름을 입력하세요: " "Type the resource group name to continue: ")" answer
    [[ "$answer" == "$RG" ]] || die "이름이 일치하지 않아 중단합니다." "Name mismatch, aborting."
  fi
fi

# Cost Management budgets can outlive their resource group.
if [[ -n "$BUDGET_IDS" ]]; then
  msg "리소스 그룹 범위의 예산 삭제" "Deleting resource-group-scoped budgets"
  while IFS= read -r budget_id; do
    az rest --url "$budget_id?api-version=2024-08-01" --method delete -o none
  done <<< "$BUDGET_IDS"
fi

if [[ "$EXISTS" == false ]]; then
  msg "리소스 그룹 '$RG' 이(가) 없습니다. 로컬 파일을 정리합니다." "Resource group '$RG' not found. Cleaning local files."
else
  # A workspace deleted with its resource group stays soft-deleted for 14 days; force-delete it so the name is freed.
  if [[ -n "${WORKSPACE:-}" ]]; then
    EXISTING_WORKSPACE="$(az monitor log-analytics workspace list -g "$RG" --query "[?name=='$WORKSPACE'].name | [0]" -o tsv)"
    if [[ -n "$EXISTING_WORKSPACE" ]]; then
      az monitor log-analytics workspace delete -g "$RG" -n "$WORKSPACE" --force true --yes -o none
    fi
  fi

  if [[ "$WAIT" == true ]]; then
    az group delete -n "$RG" --yes
    msg "삭제 완료." "Deleted."
  else
    az group delete -n "$RG" --yes --no-wait
    msg "삭제를 시작했습니다 (백그라운드, 약 3~5분)." "Deletion started in the background (about 3-5 minutes)."
    msg "확인: az group exists -n $RG   (false 가 나오면 완료)" "Check: az group exists -n $RG   (false means done)"
  fi
fi

rm -f "$ENV_FILE" "$ROOT_DIR/.lab-key" "$ROOT_DIR/.lab-key.pub"
msg "로컬 임시 파일(.lab.env, .lab-key*)을 삭제했습니다." "Removed local files (.lab.env, .lab-key*)."
msg "Cost Management 예산(모듈 4)을 구독 범위로 만들었다면 포털에서 직접 삭제하세요." \
    "If you created the Module 4 budget at subscription scope, delete it manually in the portal."
