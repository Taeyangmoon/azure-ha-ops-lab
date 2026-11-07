# 모듈 1. 고가용성 (15분)

[← 모듈 0](00-prepare.md) | [다음: 모듈 2 →](02-monitoring.md)

## 학습 목표

- 로드 밸런서가 요청을 여러 인스턴스에 분산하는 것을 확인한다.
- 인스턴스 1대가 멈춰도 서비스가 유지되는 것을 확인한다.
- **상태 프로브**가 장애 인스턴스를 자동으로 분리하는 원리를 이해한다.

## 핵심 개념

- **부하 분산**: Load Balancer가 요청을 여러 서버에 나눠 보냅니다.
- **상태 프로브**: Load Balancer가 5초마다 각 인스턴스의 `/` 를 호출합니다. 2번 연속 실패하면 그 인스턴스로는 요청을 보내지 않습니다.
- **가용성 영역**: 같은 리전 안의 물리적으로 분리된 데이터센터입니다. 인스턴스가 영역에 분산되어 있어 한 영역에 문제가 생겨도 나머지가 서비스합니다.

## 1단계. 부하 분산 확인 (5분)

```bash
source .lab.env
scripts/curl-loop.sh 20
```

예상 결과 (인스턴스 이름은 다를 수 있습니다):

```text
     9 web000000 (zone 1)
    11 web000001 (zone 2)
```

두 인스턴스가 모두 응답합니다. 브라우저에서 `http://<LB_IP>` 를 새로고침하며 이름이 바뀌는지 봐도 됩니다. (브라우저는 연결을 재사용해서 같은 인스턴스가 계속 보일 수 있습니다. 시크릿 창이나 `curl` 이 더 확실합니다.)

**포털에서 보기**: 리소스 그룹 → `halab-lb` → **설정 > 백 엔드 풀** 에서 인스턴스 2대, **모니터링 > 메트릭 > Health Probe Status** 가 100%인지 확인합니다.

## 2단계. 인스턴스 1대 중지 (5분)

터미널을 하나 더 열어(`source .lab.env` 실행) 계속 요청을 보냅니다.

```bash
# 터미널 B: 1초 간격으로 응답 확인
while true; do curl -fsS --max-time 2 -H 'Connection: close' http://$LB_IP/whoami.txt || echo "FAILED"; sleep 1; done
```

원래 터미널에서 인스턴스 0번을 중지(할당 취소)합니다.

```bash
az vmss deallocate -g $RG -n $VMSS --instance-ids 0
```

터미널 B에서 **한 인스턴스 이름만** 나오고, `FAILED` 가 없거나 거의 없는 것을 확인합니다. 중지 직후 몇 초는 일부 요청이 실패할 수 있습니다. 이것이 상태 프로브가 장애를 감지하는 데 걸리는 시간(약 10초)입니다.

```bash
scripts/curl-loop.sh 20      # 남은 인스턴스만 응답
az vmss list-instances -g $RG -n $VMSS --expand instanceView --query "[].{instance:instanceId, name:osProfile.computerName, state:instanceView.statuses[?starts_with(code,'PowerState')].displayStatus | [0]}" -o table
```

## 3단계. 복구 (3분)

```bash
az vmss start -g $RG -n $VMSS --instance-ids 0
scripts/curl-loop.sh 20      # 1~2분 뒤 다시 두 인스턴스가 응답
```

## 더 해보기: 프로세스만 죽이면? (선택)

VM은 켜져 있어도 웹 서버가 죽으면 프로브가 실패해 트래픽이 분리됩니다.

```bash
az vmss run-command invoke -g $RG -n $VMSS --instance-id 1 --command-id RunShellScript --scripts "systemctl stop nginx"
scripts/curl-loop.sh 20      # 약 10초 후 인스턴스 0번만 응답
az vmss run-command invoke -g $RG -n $VMSS --instance-id 1 --command-id RunShellScript --scripts "systemctl start nginx"
```

## 정리하며

- 인스턴스 2대 + 로드 밸런서 + 상태 프로브 = 1대 장애에도 서비스 유지.
- 하지만 **누군가 이 장애를 알아야** 고칠 수 있습니다. 다음 모듈에서 인스턴스 내부 상태를 볼 수 있게 만듭니다.
- 한계: 지금은 2대뿐이라 1대가 멈추면 남은 1대가 모든 부하를 받습니다. 모듈 3에서 자동 확장으로 보완합니다.

다음 → [모듈 2. 모니터링](02-monitoring.md)
