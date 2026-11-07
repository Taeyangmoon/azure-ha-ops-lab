# 정리 (5분)

[← 모듈 4](04-cost.md) | [README](../../README.md)

랩에서 만든 리소스는 하나의 리소스 그룹에 있습니다. `cleanup.sh` 는 먼저 해당 그룹 범위의 Cost Management 예산을 명시적으로 삭제한 뒤, 그룹과 VMSS, 로드 밸런서, 작업 영역, 경고, 자동 크기 조정, 데이터 수집 규칙을 삭제합니다. **리소스 그룹만 삭제하면 예산이 남을 수 있습니다.**

```bash
source .lab.env      # 이미 불러왔다면 생략
scripts/cleanup.sh
```

확인 문구가 나오면 리소스 그룹 이름(`rg-ha-ops-lab`)을 입력합니다. 삭제는 백그라운드로 진행됩니다(약 3~5분).

```bash
az group exists -n rg-ha-ops-lab      # false 가 나오면 완료
```

옵션:

- `scripts/cleanup.sh -y` 확인 없이 삭제
- `scripts/cleanup.sh --wait` 삭제가 끝날 때까지 대기

`.lab.env` 가 없다면 기본 그룹을 자동으로 삭제하지 않습니다. Azure 구독을 먼저 확인하고, `RESOURCE_GROUP="<실제로 배포한 그룹>" scripts/cleanup.sh` 로 삭제 대상을 명시하세요. 그룹이 이미 없어도 남은 그룹 범위 예산을 정리합니다. 예산 조회·삭제에는 모듈 4의 Cost Management 권한이 필요합니다. 조회나 삭제가 실패하면 스크립트가 오류로 종료하고 로컬 파일을 보존하므로, 문제를 해결한 뒤 다시 실행할 수 있습니다.

## 확인 체크리스트

- [ ] `az group exists` 결과가 `false`
- [ ] 그룹 범위의 예산도 `cleanup.sh` 로 삭제
- [ ] 구독 범위로 만든 예산이 있다면 포털에서 삭제
- [ ] Codespace가 더 필요 없다면 [github.com/codespaces](https://github.com/codespaces) 에서 삭제 (사용하지 않으면 자동 중지되지만 저장 공간은 남습니다)

수고하셨습니다!
