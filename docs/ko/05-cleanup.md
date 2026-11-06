# 정리 (5분)

[← 모듈 4](04-cost.md) | [README](../../README.md)

랩에서 만든 모든 리소스는 하나의 리소스 그룹에 있습니다. 그룹을 지우면 VMSS, 로드 밸런서, 작업 영역, 경고, 자동 크기 조정, 데이터 수집 규칙, 그리고 리소스 그룹 범위의 예산이 함께 삭제됩니다.

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

## 확인 체크리스트

- [ ] `az group exists` 결과가 `false`
- [ ] 구독 범위로 만든 예산이 있다면 포털에서 삭제
- [ ] Codespace가 더 필요 없다면 [github.com/codespaces](https://github.com/codespaces) 에서 삭제 (사용하지 않으면 자동 중지되지만 저장 공간은 남습니다)

수고하셨습니다!
