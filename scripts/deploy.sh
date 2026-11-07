#!/usr/bin/env bash
# Module 0: deploy VNet, Load Balancer, VM Scale Set (2 instances) and Log Analytics with Bicep.
# Usage: scripts/deploy.sh   (env: LOCATION, RESOURCE_GROUP, VM_SIZE, USE_ZONES=true|false, LAB_LANG)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOCATION="${LOCATION:-koreacentral}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ha-ops-lab}"
KEY_FILE="$ROOT_DIR/.lab-key"

require_login
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
SUB_NAME="$(az account show --query name -o tsv)"
msg "구독: $SUB_NAME / 리전: $LOCATION / 리소스 그룹: $RESOURCE_GROUP" \
    "Subscription: $SUB_NAME / Region: $LOCATION / Resource group: $RESOURCE_GROUP"

msg "[1/5] 리소스 공급자 등록 (최초 1회, 몇 분 걸릴 수 있음)" "[1/5] Registering resource providers (first time only)"
for ns in Microsoft.Compute Microsoft.Network Microsoft.OperationalInsights Microsoft.Insights; do
  az provider register --namespace "$ns" --wait >/dev/null
done

msg "[2/5] 리소스 그룹 생성" "[2/5] Creating resource group"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --tags project=azure-ha-ops-lab env=workshop -o none

msg "[3/5] SSH 키 준비 (VM 프로필용, 접속에는 사용하지 않음)" "[3/5] Preparing SSH key (required by the VM profile, not used to log in)"
[[ -f "$KEY_FILE" ]] || ssh-keygen -q -t rsa -b 4096 -N "" -f "$KEY_FILE"

msg "[4/5] Bicep 배포 (약 5~8분)" "[4/5] Deploying Bicep (about 5-8 minutes)"
az deployment group create \
  -g "$RESOURCE_GROUP" \
  -n main \
  -f "$ROOT_DIR/infra/main.bicep" \
  -p sshPublicKey="$(cat "$KEY_FILE.pub")" vmSize="${VM_SIZE:-Standard_B2s_v2}" useAvailabilityZones="${USE_ZONES:-true}" \
  -o none

get() { az deployment group show -g "$RESOURCE_GROUP" -n main --query "properties.outputs.$1.value" -o tsv; }

cat > "$ENV_FILE" <<EOF
export RG="$RESOURCE_GROUP"
export SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export LOCATION="$LOCATION"
export VMSS="$(get vmssName)"
export LB_IP="$(get lbPublicIp)"
export LB_FQDN="$(get lbFqdn)"
export WORKSPACE="$(get workspaceName)"
export WORKSPACE_ID="$(get workspaceCustomerId)"
export LAB_LANG="$LAB_LANG"
EOF
source "$ENV_FILE"

msg "[5/5] 웹 서버 준비 대기 (cloud-init 설치 중, 최대 5분)" "[5/5] Waiting for the web servers (cloud-init is installing nginx, up to 5 min)"
READY=false
for i in $(seq 1 30); do
  if curl -fsS --max-time 3 "http://$LB_IP/whoami.txt" >/dev/null 2>&1; then
    READY=true
    msg "준비 완료!" "Ready!"
    break
  fi
  sleep 10
done
[[ "$READY" == true ]] || die "웹 서버가 준비되지 않았습니다. .lab.env 는 보존했습니다. cloud-init/nginx 상태를 확인하거나 scripts/cleanup.sh 로 정리하세요." \
    "Web servers did not become ready. Kept .lab.env. Check cloud-init/nginx or run scripts/cleanup.sh."

echo
msg "웹 주소: http://$LB_IP  ($LB_FQDN)" "Web URL: http://$LB_IP  ($LB_FQDN)"
msg "다음 명령으로 변수를 불러오세요:  source .lab.env" "Load the variables with:  source .lab.env"
