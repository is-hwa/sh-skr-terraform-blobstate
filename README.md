# sh-skr-terraform-blobstate

Azure Private DNS A 레코드를 요청 단위로 생성·수정·삭제하는 Terraform 모듈과, state를 Azure Blob Storage 원격 backend로 관리하는 Azure DevOps 파이프라인입니다. 이전 Application Gateway 파이프라인(local backend 기반)의 구조를 그대로 이어받되, state 저장소를 Blob으로 전환한 버전입니다.

## 개요

각 요청(REQUEST_ID)마다 DNS 레코드 하나의 스펙을 받아 기존 tfvars 스냅샷에 병합하는 방식은 동일하며, 차이점은 다음과 같습니다.

- state backend가 `local` → `azurerm`(Blob Storage)으로 전환
- 파이프라인 최초 단계에서 state 저장소(Resource Group / Storage Account / Container)를 idempotent하게 준비하는 `Bootstrap` 단계 추가

## 파일 구성

| 파일 | 역할 |
|---|---|
| `provider.tf` | azurerm provider(4.74.0) 및 `backend "azurerm"` 선언 (RG: `TEST-AKS-RG`, Storage Account: `shtesttfstate`, Container: `tfstate`) |
| `variable.tf` | `private_dns_records` 변수 정의 (map(object)). RG, DNS Zone, 레코드 이름, TTL, records |
| `data.tf` | 레코드가 속한 Resource Group 조회 |
| `main.tf` | `azurerm_private_dns_a_record` 리소스를 `for_each`로 생성 |
| `azure-pipelines.yml` | State 저장소 준비 → tfvars 병합 → Terraform Init/Plan/Apply → 결과 콜백 파이프라인 |

## 변수 구조 (`private_dns_records`)

```hcl
private_dns_records = {
  "<key>" = {
    resource_group_name = string
    dns_zone_name        = string
    name                 = string
    ttl                  = number
    records              = list(string)
  }
}
```

## 파이프라인 동작 흐름

`REQUEST_ID`, `PROJECT`, `ACTION`(create/update/delete), `ENV`, `VARIABLE`(단일 레코드 스펙 JSON)을 파라미터로 받습니다.

1. **Bootstrap** — state 저장소가 없으면 생성 (Resource Group → Storage Account → Container 순, 각 단계 `show`로 존재 확인 후 없을 때만 `create`)
2. **Prepare** — 요청 스펙을 `STATE_DIR`의 기존 `records.auto.tfvars.json`에 병합(upsert/delete), Blob backend용 `backend.hcl`(key 경로) 생성
3. **Init** — `backend.hcl`로 `terraform init` (Blob Storage에 state 연결)
4. **Plan** — 병합된 tfvars로 `terraform plan`, 결과를 `tfplan.json`으로 저장
5. **NotifyPlanSuccess** — Plan 결과를 `/api/plan/success`로 전송
6. **Apply** — `terraform-apply-approval` 환경 승인 후 `terraform apply`, 적용된 tfvars를 `STATE_DIR`에 재저장
7. **NotifyApplySuccess** — 최종 성공을 `/api/pipeline/success`로 전송
8. **HandleFailure** — 이전 단계 실패 시 `error.log`를 읽어 `/api/pipeline/failed`로 실패 사유 전송

## State 관리 방식

- Terraform state: Blob Storage container `tfstate` 내 `${ENV}/${PROJECT}/${STACK}/terraform.tfstate` 경로에 저장 (`backend.hcl`의 `key`로 지정)
- 병합용 tfvars 스냅샷(`records.auto.tfvars.json`)은 `STATE_DIR`(로컬/에이전트 경로)에 별도 보관되어, 다음 요청 병합 시 "현재 관리 중인 레코드 목록"의 기준이 됨
- state(Blob)와 tfvars 스냅샷(에이전트 로컬)이 분리되어 있으므로, 에이전트가 교체되거나 `STATE_DIR`이 유실되면 두 값의 정합성이 깨질 수 있음 — 별도 백업 또는 Blob으로 스냅샷까지 이전하는 방안 검토 필요

## 참고 / 제약 사항

- `Bootstrap` 단계는 Storage Account 접근 키를 조회해 컨테이너 존재 여부를 확인하므로, 서비스 커넥션(`sh2-service-connection`)에 해당 권한이 있어야 함
- Application Gateway 파이프라인과 마찬가지로 알림 API 엔드포인트(`13.124.121.66:8000`)가 하드코딩되어 있음
- Application Gateway 버전과 달리 `checkout: none`을 명시적으로 추가해 불필요한 소스 체크아웃을 생략함 (Prepare 단계 제외)
