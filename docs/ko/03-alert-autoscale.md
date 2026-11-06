# 모듈 3. 경고와 자동 크기 조정 (25분)

[← 모듈 2](02-monitoring.md) | [다음: 모듈 4 →](04-cost.md)

## 학습 목표

- 문제가 생기면 사람에게 알려 주는 **경고 규칙 + 작업 그룹**을 만든다.
- 부하에 따라 인스턴스 수를 바꾸는 **자동 크기 조정**을 만든다.
- 부하를 걸어 **확장과 경고가 동시에 일어나는 것**을 확인한다.

## 핵심 개념

| 구성 요소 | 역할 |
|---|---|
| 메트릭 경고 규칙 | "CPU 평균이 5분간 70%를 넘으면" 같은 조건을 1분마다 평가 |
| 작업 그룹 | 경고가 발생했을 때 **누구에게 어떻게** 알릴지 (이메일, SMS, 웹훅 등) |
| 자동 크기 조정 | 조건에 따라 인스턴스 수를 최소~최대 범위에서 늘리거나 줄임 |

경고는 **사람에게 알리고**, 자동 크기 조정은 **시스템이 스스로 대응**합니다. 둘은 같은 CPU 메트릭을 보지만 하는 일이 다릅니다.

## 1단계. 작업 그룹 (이메일) 만들기 (3분)

```bash
source .lab.env
export EMAIL="me@example.com"      # 실제로 받을 수 있는 주소로 바꾸세요

az monitor action-group create -g $RG -n ag-halab --short-name halab \
  --action email ops-admin "$EMAIL" -o none
```

`Azure Monitor` 에서 확인 메일이 올 수 있습니다. 포털: 모니터 → 경고 → **작업 그룹** 에서 확인합니다.

## 2단계. CPU 경고 규칙 만들기 (5분)

```bash
VMSS_ID=$(az vmss show -g $RG -n $VMSS --query id -o tsv)
AG_ID=$(az monitor action-group show -g $RG -n ag-halab --query id -o tsv)

az monitor metrics alert create -g $RG -n alert-halab-cpu-high \
  --scopes $VMSS_ID \
  --condition "avg Percentage CPU > 70" \
  --window-size 5m --evaluation-frequency 1m \
  --severity 2 \
  --action $AG_ID \
  --description "VMSS average CPU above 70% for 5 minutes" -o none
```

| 옵션 | 의미 |
|---|---|
| `--condition` | 평균 CPU가 70% 초과 |
| `--window-size 5m` | 최근 5분 데이터를 본다 |
| `--evaluation-frequency 1m` | 1분마다 평가한다 |
| `--severity 2` | 심각도 (0 치명 ~ 4 정보) |

포털: 모니터 → 경고 → **경고 규칙** 에서 `alert-halab-cpu-high` 를 확인합니다.

## 3단계. 자동 크기 조정 규칙 만들기 (7분)

```bash
# 최소 2대, 최대 4대, 기본 2대
az monitor autoscale create -g $RG -n autoscale-halab \
  --resource $VMSS --resource-type Microsoft.Compute/virtualMachineScaleSets \
  --min-count 2 --max-count 4 --count 2 -o none

# 확장: 3분 평균 CPU > 70% 이면 1대 추가
az monitor autoscale rule create -g $RG --autoscale-name autoscale-halab \
  --condition "Percentage CPU > 70 avg 3m" --scale out 1 --cooldown 3 -o none

# 축소: 5분 평균 CPU < 30% 이면 1대 제거
az monitor autoscale rule create -g $RG --autoscale-name autoscale-halab \
  --condition "Percentage CPU < 30 avg 5m" --scale in 1 --cooldown 5 -o none

# 크기 조정이 일어나면 이메일 발송
az monitor autoscale update -g $RG -n autoscale-halab --add-action email "$EMAIL" -o none
```

> **설계 포인트**: 확장 기준(70%)과 축소 기준(30%) 사이에 **충분한 간격**을 둡니다. 간격이 좁으면 늘렸다 줄였다를 반복(flapping)합니다. 쿨다운은 한 번 조정한 뒤 다음 조정까지 기다리는 시간입니다.

포털: 모니터 → **자동 크기 조정** → `$VMSS` 에서 규칙 2개를 확인합니다.

## 4단계. 부하 걸기 (2분)

```bash
scripts/stress.sh start 900
```

`stress` 도구가 모든 인스턴스의 CPU를 15분간 100% 가까이 사용합니다. (`az vmss run-command` 를 쓰므로 SSH가 필요 없습니다.)

## 5단계. 확장과 경고 관찰 (8분)

1~2분 뒤부터 아래를 반복해 확인하세요.

**① 인스턴스 수**

```bash
az vmss list-instances -g $RG -n $VMSS --query "[].{id:instanceId, name:osProfile.computerName, state:provisioningState}" -o table
```

CPU가 70%를 넘고 3분 정도 지나면 인스턴스가 **3대**가 됩니다. (새 인스턴스에는 부하가 없어서 평균이 70% 아래로 내려가면 3대에서 멈춥니다. 정상입니다.)

**② 새 인스턴스가 서비스에 참여하는지**

```bash
scripts/curl-loop.sh 30      # 새 인스턴스가 부팅(약 3~5분)을 마치면 3개 이름이 보입니다
```

**③ 포털에서 보기**

- 모니터 → 자동 크기 조정 → `autoscale-halab` → **실행 기록**: 확장 이벤트
- 모니터 → 경고: `alert-halab-cpu-high` 가 **발생(Fired)** 상태. 이메일도 확인하세요.
- Log Analytics에서 모듈 2의 Q2(CPU 추이)와 아래 쿼리(인스턴스 수)를 실행해 보세요.

```kusto
Heartbeat
| where TimeGenerated > ago(1h)
| summarize Instances = dcount(Computer) by bin(TimeGenerated, 1m)
| render timechart
```

**④ (선택) 명령줄로 이벤트 보기**

```bash
az monitor activity-log list -g $RG --offset 1h \
  --query "[?contains(operationName.localizedValue, 'utoscale')].{time:eventTimestamp, op:operationName.localizedValue, status:status.localizedValue}" -o table
```

## 6단계. 부하 중지

```bash
scripts/stress.sh stop
```

CPU가 내려가면 경고가 **해결됨(Resolved)** 으로 바뀌고 해결 메일이 옵니다. 자동 축소는 CPU가 30% 미만으로 5분 이상 유지된 뒤에 일어납니다. 기다리기 어렵다면 그대로 모듈 4와 정리로 넘어가도 됩니다.

## 정리하며

```text
부하 증가 → CPU 상승 ─┬→ 경고 규칙 → 작업 그룹 → 운영자에게 이메일   (사람이 안다)
                      └→ 자동 크기 조정 → 인스턴스 추가              (시스템이 대응한다)
```

## 문제 해결

| 증상 | 해결 |
|---|---|
| CPU 메트릭이 오르지 않음 | `stress` 가 실행 중인지: `az vmss run-command invoke -g $RG -n $VMSS --instance-id 0 --command-id RunShellScript --scripts "systemctl status lab-stress --no-pager"` |
| 확장이 안 일어남 | 자동 크기 조정은 메트릭 지연 때문에 평균 3분 + 평가 시간이 필요합니다. 5~10분 기다리세요 |
| 확장 시 `QuotaExceeded` | 구독 vCPU 할당량 부족. 실행 기록의 오류를 확인하고 최대 개수를 줄이세요 |
| 경고 메일이 안 옴 | 스팸함 확인, 작업 그룹의 **테스트** 버튼으로 발송 확인 |

다음 → [모듈 4. 비용](04-cost.md)
