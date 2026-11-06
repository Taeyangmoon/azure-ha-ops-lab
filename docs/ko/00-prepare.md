# 모듈 0. 준비 (10분)

[← README](../../README.md) | [다음: 모듈 1 →](01-high-availability.md)

## 학습 목표

- Bicep(인프라를 코드로 정의)으로 실습 환경 전체를 한 번에 배포한다.
- 배포된 구성 요소의 역할을 이해한다.

## 만들어지는 리소스

| 리소스 | 역할 |
|---|---|
| VNet + NSG | 웹 서버가 놓이는 네트워크. NSG는 80 포트(HTTP)만 허용 |
| 공용 IP + Azure Load Balancer (Standard) | 외부 요청을 받아 정상 인스턴스로 분산. 상태 프로브(5초 간격)로 건강 확인 |
| Virtual Machine Scale Set (2대) | 같은 웹 서버(nginx)를 여러 대 운영. 가용성 영역 1~3에 분산 배치 |
| Log Analytics 작업 영역 | 모니터링 데이터를 저장하고 KQL로 조회하는 곳 |

모든 리소스에는 `project=azure-ha-ops-lab`, `env=workshop` **태그**가 붙습니다 (모듈 4에서 사용).

## 실습

### 1. 로그인 확인

```bash
az login --use-device-code      # 아직 로그인하지 않았다면
az account show --query name -o tsv
```

> 구독이 여러 개라면 `az account set --subscription "<구독 이름 또는 ID>"` 로 선택하세요.

### 2. 배포

```bash
scripts/deploy.sh
```

약 5~8분 걸립니다. 기다리는 동안 [`infra/main.bicep`](../../infra/main.bicep) 을 열어 보세요. 위 표의 리소스가 코드로 어떻게 표현되는지 볼 수 있습니다.

기본값은 `koreacentral` 리전, `Standard_B2s_v2` 크기입니다. 바꾸려면:

```bash
LOCATION=japaneast VM_SIZE=Standard_D2s_v5 scripts/deploy.sh
```

### 3. 변수 불러오기

```bash
source .lab.env
echo $LB_IP
```

이 변수(`RG`, `VMSS`, `LB_IP`, `WORKSPACE` 등)는 이후 모듈에서 계속 사용합니다. **터미널을 새로 열면 `source .lab.env` 를 다시 실행**하세요.

### 4. 확인

```bash
curl http://$LB_IP/whoami.txt
az vmss list-instances -g $RG -n $VMSS --query "[].{instance:instanceId, name:osProfile.computerName, zone:zones[0], state:provisioningState}" -o table
```

브라우저에서 `http://<LB_IP>` 를 열어도 됩니다. 인스턴스 이름이 보이면 성공입니다.

## 문제 해결

| 증상 | 해결 |
|---|---|
| `QuotaExceeded` / 코어 부족 | 다른 리전 또는 `VM_SIZE` 변경. 할당량 확인: `az vm list-usage -l $LOCATION -o table` |
| `SkuNotAvailable` (예: `Standard_B2s` 용량 제한) | 다른 크기 사용: `VM_SIZE=Standard_B2s_v2 scripts/deploy.sh`. 가용 크기: `az vm list-skus -l $LOCATION --resource-type virtualMachines -o table` |
| `SkuNotAvailable` / 영역 관련 오류 | `USE_ZONES=false scripts/deploy.sh` (영역 미지원 리전/크기) |
| 배포 후 `curl` 이 응답 없음 | 인스턴스가 nginx를 설치하는 중입니다. 1~3분 후 다시 시도 |
| 이름 충돌 | `RESOURCE_GROUP=rg-ha-ops-lab2 scripts/deploy.sh` |

다음 → [모듈 1. 고가용성](01-high-availability.md)
