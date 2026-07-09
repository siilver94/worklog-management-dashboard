# CLAUDE.md — 업무현황판 (Worklog Management Dashboard)

> Claude 전용 핸드오프 문서. 새 세션 시작 시 이 파일 + 작업할 화면의 `.powerfx`를 첨부할 것.
> GitHub: https://github.com/siilver94/PowerApps_worklog-management-dashboard

---

## 0. 이 문서를 읽는 Claude에게 (필독)

이 앱은 **103명이 매일 쓰는 실서비스**다. 그리고 **개발자(김은성 주임)는 Power Fx 코드 자체에는 약하고, 요구사항 중심으로 대화**한다. 다음을 반드시 지킬 것:

1. **Delegation·성능을 항상 먼저 고려한다.** Daily_DB는 연 45,000건 이상 쌓이고, PowerApps 위임 한도는 기본 2,000건이다. 어떤 코드를 주든 위임 가능 여부를 먼저 판단하고, 위임 불가 시 경고 + 대안을 함께 제시한다.
2. **요구사항을 정확히 파악한 뒤 코드를 준다.** 바로 코드부터 던지지 말고, 동작·기능을 먼저 정리하고 합의한 뒤 구현한다. 더 나은 구조가 있으면 먼저 제안하고 선택하게 한다.
3. **코드는 `=` 접두사 없이**, 실제 동작하는 완성본으로 준다. 적용 위치(컨트롤 + 속성 + 화면)를 항상 명시한다.
4. **한 번에 한 곳씩 고친다.** 전체를 갈아엎으면 다른 화면 참조가 깨진다.
5. **컬럼명은 문자열로 감싸지 않는다.** `Filter(테이블, 작성자 in ...)` 처럼 컬럼을 직접 참조한다. `"작성자"` 처럼 쌍따옴표로 감싸면 문자열 비교가 되어 필터가 깨진다.
6. **속성값은 한 줄씩 명확히 준다.** `X=465/Y=124` 같은 함축 표기 금지. 컨트롤 타입·이름·X·Y·Width·Height를 각각 별도 줄로. UI 작업은 STEP별로 적용 → 스크린샷 확인 → 다음 단계로 진행한다.
7. **내가 준 주석/안내 줄을 그대로 붙여넣는 경우가 있다.** 코드를 줄 때 "이 줄은 지워라" 같은 안내가 실제 코드에 섞이지 않도록, 붙여넣을 최종 코드만 깔끔하게 준다. (다음주 이동 버튼에서 `+7` 후 `-7` 주석이 같이 들어가 제자리로 돌아간 사고 있었음)
8. **코드가 여러 번 수정되며 꼬이면, 사용자에게 현재 전체 코드를 받아 처음부터 통짜로 다시 준다.** 부분 수정 지시가 누적되면 중복·순서 꼬임이 생긴다. (View_Screen.OnVisible에서 실제로 겪음)

---

## 1. 프로젝트 개요

TYM 중앙기술연구소 내부 업무 관리 앱.

| 항목 | 내용 |
|------|------|
| 플랫폼 | Microsoft PowerApps Canvas App → Microsoft Teams 탭 배포 |
| 데이터 | SharePoint Lists (Dataverse·프리미엄 커넥터 불가 — 무료 플랜) |
| 사용자 | 약 103명, 매일 업무일지 작성 (실서비스 운영 중) |
| 개발자 | 김은성 주임 (단독 개발·유지보수) |
| 자동화 | Power Automate 표준 커넥터·기본 흐름만 (HTTP·프리미엄 불가) |

---

## 2. 화면 구성 (5개 스크린 + 1 미사용)

| 파일 | 화면명 | 역할 |
|------|--------|------|
| `App.OnStart.powerfx` | 앱 전역 | 전역변수 초기화, 컬렉션 캐싱, 사용자 정보·권한 로드 |
| `Daily_Screen.powerfx` | 업무일지 | 날짜별 업무일지 작성/수정/삭제, 달력, Task 추가, 작업_분류 선택 |
| `Task_Screen.powerfx` | 업무현황 | 칸반보드(시작전/진행중/완료), Task 등록/수정, 프로젝트 관리 모달 |
| `View_Screen.powerfx` | 업무조회 | 팀별/프로젝트별 주간 매트릭스 조회, 피드백 작성 |
| `DashB_Screen.powerfx` | 대시보드 | 업무계정/프로젝트/작업분류 분포 차트, KPI, 기간 필터 |
| `cal_Screen.powerfx` | (미사용) | — |

---

## 3. 데이터 구조 (SharePoint Lists)

### 계층 구조
```
Project_DB (프로젝트 마스터)
    └── Task_DB (개인 업무 등록 — Project_DB 참조)
            └── Daily_DB (매일 업무일지 — Task_DB 참조)
```
- **Project_DB**: 회사가 관리하는 프로젝트 마스터. 사용자가 여기서 진행할 프로젝트를 고른다.
- **Task_DB**: 사용자가 Project_DB의 프로젝트를 골라 "내 업무"로 등록.
- **Daily_DB**: 사용자가 매일 Task_DB의 업무를 골라 그날 작업내용·시간을 기록.

### Project_DB — 프로젝트 마스터 (약 68~80건, 소규모)
| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| ID | Int | PK |
| 상태 | Text | 시작전 / 진행중 / 완료 |
| 연구비_계정 | Text | 개발비 등 |
| 업무_계정 | Text | 제품개발/기술개발/원가절감/설계변경/TF/교육/기타업무/연차(반차)/출장/연구관리 |
| 프로젝트명 | Text | |
| PM | Text | |
| 관련기종명 | Text | |
| 시작날짜 / 종료날짜 | Date | |
| 비고 | Text | |
| 만든 날짜(Created) | DateTime | 시스템 자동 |
| 금액(견본/용역/시작품/특허/신뢰성/WPBC) | Int | |

> **소규모라 delegation 한도에 안 걸린다.** 프로젝트 전체 목록이 필요하면 Project_DB를 직접 쓰는 게 안전.

> ⚠️ **OData 내부 컬럼명 주의.** Project_DB의 한글 컬럼은 내부적으로 인코딩된다. 프로젝트명 = `OData__xd504__xb85c__xc81d__xd2b8__xba`, 시작날짜 = `OData__xc2dc__xc791__xb0a0__xc9dc_`, 종료날짜 = `OData__xc885__xb8cc__xb0a0__xc9dc_`, 상태 = `OData__xc0c1__xd0dc_`, 업무_계정 = `OData__xad6c__xbd84___xc5c5__xbb34_`, 비고 = `OData__xbe44__xace0_`. `SortByColumns` 등 컬럼명을 문자열로 받는 함수에서만 이 인코딩명을 쓰고, `Filter`·`Patch`의 레코드 표기에서는 한글 컬럼명을 그대로 쓴다.

### Task_DB — 개인 업무 등록 (2,500건+)
| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| ID | Int | PK |
| 작성자 | Text | 이름_한글 |
| 업무_계정 / 프로젝트명 / PM / 시작날짜 / 종료날짜 / 관련기종명 | — | Project_DB에서 가져옴 |
| 업무제목 | Text | |
| 업무_시작일자 / 업무_종료일자 | Date | 개인 업무 기간 |
| 관련ECN / 업무요청자 / 비고 | Text | |
| 상태 | Text | 시작전 / 진행중 / 완료 |
| 상세_업무내용 | Text | |

> ⚠️ **`Distinct`·`in` 연산자는 위임 불가.** Task_DB(2,500건+)에서 `Distinct(...)`나 `작성자 in colXxx.이름_한글` 으로 필터하면 앞 500~2,000건만 로컬 처리되어 **최근 등록 데이터가 누락**된다. → colProjectList를 Task_DB에서 뽑던 방식을 폐기하고 colTeamWeekDaily 기반으로 전환함(§8 참고).

### Daily_DB — 일일 업무일지 (월 ~3,800건, 연 ~45,000건+) ⚠️ 대용량
| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| ID | Int | PK |
| 작성일자 | Date | |
| 작성자 | Text | 이름_한글 |
| 팀 | Text | UserInfo_DB에서 자동 |
| 상태 / 업무_계정 / 프로젝트명 / 업무_시작일자 / 업무_종료일자 / 업무제목 / 상세_업무내용 | — | Task_DB 참조 |
| 작업내용 | Text | 당일 작업 내용 (사용자 직접 입력) |
| 작업시간 | Int | 당일 작업 시간 (사용자 직접 입력) |
| 피드백 | Text | 팀장/관리자 피드백 |
| 작업_분류 | Text | 업무_계정별 세부 분류 (드롭다운) |

> **이 테이블이 성능의 핵심.** 전체를 Filter로 당기면 2,000건에서 잘린다. **날짜 범위 필터는 위임 가능**하므로, 주간 등 좁은 범위는 Daily_DB 직접 호출이 오히려 정확하다.

### UserInfo_DB — 사용자 정보 (103명)
| 컬럼명 | 타입 | 설명 |
|--------|------|------|
| 이름_한글 | Text | **앱 전반의 작성자 기준 키** |
| 이름_영문 | Text | |
| e-mail | Text | 소문자 변환 후 `User().Email`과 매칭 |
| 부문 | Text | **Function / Project** 2개 |
| 팀 | Text | 가상검증팀, 외장개발팀 등 |
| 직급 | Text | 실제 직급(주임 등) |
| 직급2 | Text | **앱 권한 제어 핵심** — 팀원 / 팀장 / 부문장 / 소장 |
| 사번 | Int | PK |

---

## 4. 사용자 권한 구조 (SharePoint 권한 없음 — 100% 앱 로직)

| 직급2 | 인원 | 부문 컬럼값 | View_Screen 팀별 모드에서 보이는 범위 |
|-------|------|------------|------------------------------|
| 소장 | 1명 | 연구소장 | **전체 팀**의 팀장이 작성한 업무일지 |
| 부문장 | 2명 | Function / Project (각 1명) | **담당 부문**의 팀장이 작성한 업무일지 |
| 팀장 | 다수 | Function / Project | **본인 팀** 전원 |
| 팀원 | 다수 | Function / Project | **본인 팀** 전원 (팀장과 동일) |

- 부문은 **Function**과 **Project** 2개, 각 부문에 부문장 1명씩.
- 권한 판단 변수: `varMyRole`(직급2), `varMyTeam`(팀), `varMyDivision`(부문).
- ⚠️ **팀원도 팀 전체를 본다.** `colTargetAuthors`의 default 분기가 `Filter(colUsers, 팀 = varMyTeam)`.

---

## 5. 핵심 전역 변수

| 변수명 | 타입 | 설명 |
|--------|------|------|
| `varMyEmail` | Text | 소문자 이메일 (`Lower(User().Email)`) — **가장 먼저 세팅, 모든 사용자 매칭의 기준** |
| `varMyName` | Text | 로그인 사용자 한글 이름 (이메일로 LookUp) — **작성자 기준 키. name_label 대신 이걸 쓴다** |
| `varMyTeam` | Text | 팀명 |
| `varMyDivision` | Text | 부문명 (Function / Project) |
| `varMyRole` | Text | 팀원 / 팀장 / 부문장 / 소장 — **권한 제어 핵심** |
| `varViewMode` | Text | View_Screen 모드: "팀별" / "프로젝트별" |
| `vw_StartOfWeek` | Date | View_Screen 주간 시작일(월요일) |
| `varSelectedDate` | Date | Daily_Screen 선택 날짜 |
| `varFirstDayOfMonth` | Date | 달력 현재 월 기준 |
| `varEditMode` | Boolean | 편집 모드 여부 |
| `varFilterMode` | Text | "All" / "15Days" |
| `varProjectMode` | Text | "View" / "New" / "Edit" — 프로젝트 관리 모달 모드 |
| `varAutoHour` / `locAutoHour` | Number | 연차/반차 작업시간 자동 입력값 (전역/로컬 동기화) |
| `varShowProjectModal` | Boolean | 프로젝트 관리 모달 표시 |
| `varShowDeleteConfirm` | Boolean | 프로젝트 삭제 확인 |
| `varViewLoading` | Boolean | View_Screen 로딩 스피너 |
| `varShowToast` / `varShowToast2` | Boolean | 토스트 알림 |

> ⚠️ **`varMyRole` 세팅은 반드시 이메일 기준 LookUp으로.** `User().FullName` 파싱이나 `name_label.Text`에 의존하면 안 됨.

---

## 6. 핵심 컬렉션

| 컬렉션명 | 출처 | 설명 |
|----------|------|------|
| `colUsers` | UserInfo_DB | 사용자 캐시. 역할별 필터링·LookUp 반복 비용 제거용 |
| `colDailyTasks` | Daily_DB | Daily_Screen 우측 편집 중인 업무 목록 |
| `colDaily_365_Team` | Daily_DB | 최근 365일 내 팀 데이터 캐시 (2,000건 한도 주의) |
| `colDaily_365_All` | Daily_DB | 최근 365일 전체 데이터 캐시 (2,000건 한도 — 주간 조회에 쓰지 말 것) |
| `colTargetAuthors` | colUsers | 역할별 조회 대상 작성자 목록 (소장→전체 팀장, 부문장→부문 팀장, 팀장/팀원→팀 전원) |
| `colProjectList` | **colTeamWeekDaily** | **팀별 모드 프로젝트 목록. Task_DB가 아니라 그 주 Daily_DB(colTeamWeekDaily)에서 추출** — 위임 한계 우회 (§8) |
| `colAllProjects` | Project_DB | 프로젝트별 모드 프로젝트 목록 (Project_DB 전체) |
| `colDeselectedProjects_View` | UI | **View_Screen 프로젝트 필터 — 해제된 것만 추적.** 비동기 로딩 타이밍 문제 해결용 (§8) |
| `colDeselectedProjects` | UI | Task_Screen 프로젝트 필터 — 해제된 것만 추적 (§9) |
| `colTeamWeekDaily` | Daily_DB | View_Screen 주간 데이터 — Daily_DB 직접 호출(날짜 필터 위임) |
| `colTeamMatrix` | 가공 | View_Screen 매트릭스용 GroupBy 결과 |
| `colWorkTagsMap` | 하드코딩 | 업무_계정별 작업_분류 드롭다운 매핑 |
| `colTeamPeriodData` | Daily_DB | DashB_Screen 기간 데이터 |
| `colAccAgg` / `colProjChart` / `colWorkTagAgg` | 가공 | DashB 집계 |
| `colKoreaHolidays` | 하드코딩 | 2025~2030 공휴일 (Daily_Screen 달력 색 처리) |

---

## 7. 작업_분류 매핑 (`colWorkTagsMap`) — 중요 패턴

업무_계정별로 작업_분류 드롭다운 항목이 다르다. App.OnStart의 `colWorkTagsMap` 테이블에 `{Account, Tag, Order}` 형태로 하드코딩.

### 연구관리 계정의 프로젝트별 분기
`업무_계정 = "연구관리"`인 경우, 프로젝트명까지 조합해서 작업_분류를 다르게 한다.
- 매핑 키 형식: `"연구관리_" & 프로젝트명` (예: `"연구관리_회계"`, `"연구관리_S/W"`)
- DB에는 `작업_분류` 태그값(행정/회의 등)만 저장.

### ddWorkTag 매핑 로직 (Daily_Screen)
```
If(
    ThisItem.c업무_계정 = "연구관리",
    "연구관리_" & ThisItem.c프로젝트명,
    ThisItem.c업무_계정
)
```

### ⚠️ 작업분류 선택 시 입력값 초기화 버그 (해결됨)
- 증상: 작업시간·작업내용 입력 후 작업_분류를 선택하면 입력값이 사라짐.
- 원인: `ddWorkTag.OnChange`의 `Patch(colDailyTasks, ...)`가 갤러리 재렌더링을 유발 → TextInput이 Default로 리셋.
- 해결: OnChange의 Patch에 작업시간·작업내용도 함께 저장해서 재렌더링 전에 값을 확정.

### 연차/반차 작업시간 자동 입력 (구현됨)
- `업무_계정 = "연차(반차)"` + 작업_분류가 "연차"면 8, "오전반차"/"오후반차"면 4를 작업시간에 자동 입력.
- `ddWorkTag.OnChange` 실행 순서: **자동값 계산 → UpdateContext(locAutoHour) → Patch(작업시간에 자동값 우선) → Reset(txtWorkHour)**. 순서가 어긋나면 옛날 값이 다시 표시됨.
- `txtWorkHour.Value` = `If(!IsBlank(locAutoHour), locAutoHour, ThisItem.작업시간)`

---

## 8. View_Screen 동작 사양 (이번 세션 대폭 개선)

### 팀별 / 프로젝트별 모드
| 모드 | 프로젝트 목록 소스 | 매트릭스에 보이는 사람 |
|------|--------------------|------------------------|
| 팀별 | `colProjectList` (그 주 Daily_DB에서 추출) | `varMyRole` 권한 범위 |
| 프로젝트별 | `colAllProjects` (Project_DB 전체) | 권한 제한 없이 전 인원 |

### ⭐ colProjectList를 colTeamWeekDaily 기반으로 전환 (핵심 변경)
- **문제**: 팀별 모드에서 최근 Task_DB 항목이 누락. `colProjectList`를 Task_DB에서 `Distinct` + `작성자 in ...`으로 만들었는데 위임 한계로 최근 데이터가 잘림.
- **해결**: `colProjectList`를 **그 주 `colTeamWeekDaily`(날짜 필터 위임)에서 추출**. 그 주 팀원이 실제 작업한 프로젝트만 정확히 나옴.
```
ClearCollect(
    colProjectList,
    Sort(Distinct(AddColumns(Filter(colTeamWeekDaily, !IsBlank(프로젝트명)), Value, Trim(프로젝트명)), Value), Value, SortOrder.Ascending)
)
```

### ⭐ 프로젝트 선택 = colDeselectedProjects_View 방식 (비동기 타이밍 해결)
- **문제**: 앱 켜고 바로 업무조회 진입 시, 처음 뜬 프로젝트는 전체 선택되나 0.5~1초 후 뜨는 프로젝트는 선택 안 됨. `colTeamWeekDaily`(Daily_DB 직접 호출)가 비동기라 `colSelProjects`가 불완전 상태로 확정되기 때문.
- **해결**: `colSelProjects`(선택 추적) 폐기 → `colDeselectedProjects_View`(해제 추적). 시작이 빈 컬렉션이라 나중에 프로젝트가 떠도 자동으로 전체 선택 상태 유지.

| 컨트롤 | 속성 | 값 |
|--------|------|-----|
| `chkProj` | Checked | `IsBlank(LookUp(colDeselectedProjects_View, Value = ThisItem.Value))` |
| `chkProj` | OnCheck | `RemoveIf(colDeselectedProjects_View, Value = ThisItem.Value)` |
| `chkProj` | OnUncheck | `Collect(colDeselectedProjects_View, {Value: ThisItem.Value})` |
| `chkAll` | Checked | `IsEmpty(colDeselectedProjects_View)` |
| `chkAll` | OnCheck | `Clear(colDeselectedProjects_View)` |
| `chkAll` | OnUncheck | `ClearCollect(colDeselectedProjects_View, gal_ProjectFilter.AllItems)` |

- 매트릭스 rawRows 필터: `If(IsEmpty(colDeselectedProjects_View), baseRows, Filter(baseRows, !(Trim(프로젝트명) in colDeselectedProjects_View.Value)))`

### 주간 데이터 로딩 원칙
- `colTeamWeekDaily`는 **`Daily_DB` 직접 호출**로 그 주(월~금)만 가져온다. 날짜 범위 필터는 위임 가능 → 그 주 전 인원 데이터를 정확히 확보.
- ❌ `colDaily_365_All`(2,000건 캐시)에서 주간을 뽑으면 최신순으로 잘려서 편향 발생.

### ⭐ btnRecalcMatrix 단일화 (R-01 완료)
- 숨김 버튼 `btnRecalcMatrix`(Visible=false)에 재계산 로직을 모음: `colDeselectedProjects_View` 초기화 → `colTeamWeekDaily` 재로드 → `colProjectList` 재계산 → `colTeamMatrix` 재계산.
- **주 이동 버튼(icPrev/icnNext/ButtonCanvas4_1)·달력 클릭(gal_Calendar_Days_1)** 은 `vw_StartOfWeek` 변경 후 `Select(btnRecalcMatrix)` 한 줄만 호출.
- ⚠️ **단, `View_Screen.OnVisible`에서는 `Select(btnRecalcMatrix)`를 쓰지 않는다.** OnVisible은 버튼 렌더링 전에 실행되어 `Select()`가 무시될 수 있음 → OnVisible에서는 재계산 로직을 **직접(inline)** 실행한다.

### OnVisible 순차 실행 원칙
`colTeamWeekDaily`(비동기) → `colProjectList` → `colTeamMatrix` 순서를 엄격히 지킨다. `Concurrent`로 묶지 말 것.

---

## 9. Task_Screen 프로젝트 필터 — colDeselectedProjects 방식 (해결됨)

좌측 `GalleryProjects`에서 프로젝트를 체크/해제해 칸반 갤러리를 필터링한다.

- 기존 `colSelectedProjects`(선택 추적, Distinct/in 위임 한계로 최근 프로젝트 누락) → `colDeselectedProjects`(해제 추적)로 전환.
- 기본 전체 선택 상태, 해제한 것만 담는다.

| 위치 | 코드 |
|------|------|
| `Task_Screen.OnVisible` | `Clear(colDeselectedProjects)` |
| 체크박스 `Checked` | `IsBlank(LookUp(colDeselectedProjects, Value = ThisItem.Value))` |
| 체크박스 `OnUncheck` | `Collect(colDeselectedProjects, {Value: ThisItem.Value})` |
| 체크박스 `OnCheck` | `RemoveIf(colDeselectedProjects, Value = ThisItem.Value)` |
| 칸반 갤러리 `Items` projRows | `If(IsEmpty(colDeselectedProjects), baseRows, Filter(baseRows, !(프로젝트명 in colDeselectedProjects.Value)))` |
| `chkSelectAll.OnCheck` | `Clear(colDeselectedProjects)` |
| `chkSelectAll.OnUncheck` | `ClearCollect(colDeselectedProjects, GalleryProjects.AllItems)` |
| `chkSelectAll.Checked` | `IsEmpty(colDeselectedProjects)` |

---

## 10. 프로젝트 관리 모달 (conProjectModal) — 2패널 완성 (이번 세션 완료)

업무현황 화면의 `btnProjectManage`로 여는 프로젝트 마스터(Project_DB) 관리 모달. Form 컨트롤 제거, Patch 방식.

### 레이아웃 (1280 × 720)
```
conProjectModal (1280 × 720, X=80, Y=40)
├── recLeftBg (좌측 배경, W=380)
├── ddAccount (업무_계정 필터) + ddStatus (상태 필터: 전체/시작전/진행중/완료)
├── galProjectList (좌측 목록 — 카드형, 상태 뱃지)
├── recPanelDivider (좌/우 구분선, X=380)
└── conProjDetail (우측 상세, X=381, W=899)
    ├── recHeader / recHeaderDivider (헤더 H=72)
    ├── lblProjName (View) / txtProjName (Edit·New)
    ├── recStatusBadge / lblStatusBadge
    ├── [바디 좌] 기본 정보: 업무_계정 / PM / 관련기종명 / 시작날짜 / 종료날짜 / 상태
    │     각 필드 = lblKey_* (필드명 고정) + lblVal_* (View) + 입력컨트롤 (Edit·New)
    ├── recBodyDivider (좌/우 구분선, X=449)
    └── [바디 우] 프로젝트 현황: D-day / 진행률 바 / 등록일
```

### 좌측 갤러리 카드형 디자인 (이번 세션)
- `TemplateHeight = 76`. 카드 안: 업무_계정(상단 회색) / 프로젝트명(메인 Semibold) / 날짜 범위(하단 회색) / 상태 뱃지(우측) / 선택 강조 세로 바(recSelectedBar, `ThisItem.IsSelected`) / 카드 구분선(recItemDivider).

### 모드 토글 패턴
- `varProjectMode` = "View" / "Edit" / "New". 같은 위치에 View 라벨 + Edit 입력을 겹쳐두고 Visible로 교체.
- View 라벨: `Visible = varProjectMode = "View"`
- Edit 입력: `Visible = varProjectMode = "Edit" || varProjectMode = "New"`
- Key 라벨: 항상 표시.

### ⚠️ 컨트롤 버전 주의 — TextInput은 `.Text`, 콤보박스는 `Default`에 문자열
- 이 환경의 TextInput 값은 `.Value`가 아니라 **`.Text`**. 저장 Patch도 `txtProjName.Text` 형태.
- 콤보박스(ComboBox)는 `DefaultSelectedItems`(배열)가 아니라 **`Default`에 문자열**을 받는다. 배열(`[]`)을 넣으면 "Text 값이 필요합니다" 에러.

### 신규(New) 모드 입력 필드 초기화
각 입력 컨트롤 값에 모드 분기:
- 텍스트: `If(varProjectMode = "New", "", galProjectList.Selected.<필드>)`
- 날짜: `If(varProjectMode = "New", Today(), galProjectList.Selected.<필드>)`
- 콤보 업무_계정: `If(varProjectMode = "New", "", galProjectList.Selected.업무_계정)`
- 콤보 상태: `If(varProjectMode = "New", "시작전", galProjectList.Selected.상태)`

### 버튼 Visible (연구관리팀 전용 권한)
- `btnNewProject.Visible` = `varProjectMode = "View" && varMyTeam = "연구관리팀"`
- `btnEdit.Visible` = `varProjectMode = "View" && !IsBlank(galProjectList.Selected) && varMyTeam = "연구관리팀"`
- 저장/취소/삭제는 Edit·New 모드에서만 표시. **편집 중일 때 신규 등록 버튼 숨김.**

### ⚠️ 0으로 나누기 오류 (해결됨)
- 증상: Task_Screen 진입 시 상단에 "잘못된 작업: 0으로 나누기" 에러.
- 원인: 진행률 계산(`elapsed / total`)에서 시작날짜=종료날짜인 프로젝트가 있으면 `total=0`.
- 해결: **진행률을 쓰는 세 곳 모두**(`recProgressFill.Width`, `recProgressFill.Fill`, `lblVal_Progress.Text`)에 `If(total <= 0, ...)` 예외 처리. 한 곳만 빠져도 에러 발생.

### 우측 현황 계산식
- D-day: 완료면 "완료 ✓", 아니면 `DateDiff(Today(), 종료날짜)`. 색: 초과=빨강, 14일 이내=주황, 그 외=검정.
- 진행률: `elapsed / total * 100`. 바 Width = `380 * pct / 100`. 색: 100%+=빨강, 70%+=주황, 그 외=파랑.
- 등록일: `Text(galProjectList.Selected.'만든 날짜', "yyyy.mm.dd")`

### galProjectList.Items (업무_계정 + 상태 필터)
```
SortByColumns(
    Filter(
        Project_DB,
        (IsBlank(ddAccount.Selected.Value) || 업무_계정 = ddAccount.Selected.Value) &&
        (ddStatus.Selected.Value = "전체" || 상태 = ddStatus.Selected.Value)
    ),
    "OData__xd504__xb85c__xc81d__xd2b8__xba",
    SortOrder.Ascending
)
```

### 저장 (btnSaveProject.OnSelect)
- 검증: 프로젝트명(`txtProjName.Text`)·업무_계정(`cmbProjAccount.Selected.Value`) 필수.
- New → `Patch(Project_DB, Defaults(Project_DB), {...})`, Edit → `Patch(Project_DB, galProjectList.Selected, {...})`.
- 이후 `Refresh(Project_DB)` + `varProjectMode="View"` + 토스트.
- 삭제는 `conDeleteConfirm` 확인 후 `Remove(Project_DB, galProjectList.Selected)`.

---

## 11. 알려진 버그 목록

| 번호 | 화면 | 버그 | 상태 |
|------|------|------|------|
| B-01 | View_Screen | 주 이동 시 매트릭스 갱신 안됨 | ✅ 해결 — btnRecalcMatrix 단일화 |
| B-02 | View_Screen | 소장/부문장 화면에서 팀장 데이터 안보임 | ✅ 해결 |
| B-03 | Task/View | 프로젝트별 선택 필터 안됨 / colProjectList·colAllProjects 동일 | ✅ 해결 |
| B-04 | Task_Screen | 프로젝트 관리 신규 저장 오류 | ✅ 해결 |
| B-05 | Task_Screen | 프로젝트 관리 상태 수정 안됨 | ✅ 해결 |
| B-06 | 전체 | 특정 직원 이름 파싱 깨짐 | ✅ 해결 — name_label → varMyName |
| B-07 | Task_Screen | 프로젝트 체크박스 일부 미선택 | ✅ 해결 — colDeselectedProjects |
| B-08 | Daily_Screen | 작업분류 선택 시 입력값 초기화 | ✅ 해결 |
| B-09 | View_Screen | 팀별 모드에서 최근 Task 프로젝트 누락 | ✅ 해결 — colProjectList를 colTeamWeekDaily 기반으로 전환 |
| B-10 | View_Screen | 달력 클릭 시 프로젝트/Task 누락 | ✅ 해결 — 달력 OnSelect에 Select(btnRecalcMatrix) 추가 |
| B-11 | View_Screen | 최초 진입 시 나중에 뜬 프로젝트 체크 안됨 (비동기 타이밍) | ✅ 해결 — colDeselectedProjects_View 방식 |
| B-12 | Task_Screen | "0으로 나누기" 에러 (진행률 계산) | ✅ 해결 — 세 곳 모두 total<=0 예외 처리 |

---

## 12. 개발 예정 목록

| 번호 | 분류 | 내용 |
|------|------|------|
| F-01 | 개발 | 연장근로 시스템 (사전/사후 신청 화면) |
| F-02 | 개발 | 26년 사업 계획 프로젝트 — 종료분 완료 처리, 진행중만 표시 |
| F-03 | 개발 | 그래프 색 구분 |
| F-04 | 개발 | 팀별 작성률 표시 |
| F-06 | 개발 | 연차(반차) 색 처리 — Daily_Screen 빨간색 표시 |
| F-07 | 개발 | 출장 시스템 (작업_분류에 "출장" 항목 추가됨) |
| F-08 | 개발 | 연차 시스템 |
| F-09 | 개발 | 공지 시스템 |
| F-10 | 개발 | 기타·미분류 건 인원별 정리 (진행중) |
| R-01 | 리팩토링 | View_Screen 매트릭스 재계산 단일화 → ✅ 완료 (btnRecalcMatrix) |
| R-02 | 리팩토링 | 모든 `name_label.Text` → `varMyName` 통일 잔여분 점검 |
| P-01 | 성능 | App.OnStart 최적화 — Daily_DB 2,000건 한도 구조 개선 |

---

## 13. 이번 세션 완료 작업 (요약)

1. **프로젝트 관리 모달 완성** — 신규/편집 모드 값 초기화, 편집 중 신규 버튼 숨김, 연구관리팀 전용 권한(btnNewProject/btnEdit Visible), 0으로 나누기 오류 수정. TextInput `.Text`·콤보박스 `Default` 문자열 버전 이슈 정리.
2. **좌측 갤러리 카드형 재디자인** — TemplateHeight 76, 프로젝트명 메인 + 업무계정/날짜 서브 + 상태 뱃지 + 선택 강조 세로 바.
3. **팀별 프로젝트 누락 해결(B-09)** — colProjectList를 Task_DB(위임 한계)에서 colTeamWeekDaily 기반으로 전환.
4. **달력 클릭 누락 해결(B-10)** — gal_Calendar_Days_1 OnSelect에 Select(btnRecalcMatrix) 추가.
5. **비동기 타이밍 체크 문제 해결(B-11)** — colSelProjects → colDeselectedProjects_View(해제 추적)로 전환. 최초 진입 시에도 전체 선택 유지.
6. **btnRecalcMatrix 단일화(R-01 완료)** — 주 이동·달력 클릭은 Select(btnRecalcMatrix), OnVisible은 inline 직접 실행(렌더링 타이밍).
7. **업데이트 안내 메일 초안** 작성.

---

## 14. 다음 세션 우선순위 (추천)

1. **F-06 — 연차/반차 Daily_Screen 색 처리** (자동 시간 입력은 완료, 시각 표시만 남음).
2. **F-10 — 기타·미분류 건 인원별 정리** (진행 중).
3. **R-02 — name_label.Text → varMyName 잔여분 점검** (B-06 완전 마무리).
4. **P-01 — App.OnStart / Daily_DB 2,000건 한도 구조 개선** (근본 성능 과제).

---

## 15. 세션 시작 방법

```
1. 이 CLAUDE.md 첨부
2. 작업할 화면의 .powerfx 첨부 (예: Daily_Screen.powerfx)
3. 작업 내용 설명
   예시: "CLAUDE.md + Daily_Screen.powerfx — F-06 연차/반차 색 처리 진행"
```

### 코드 스타일 (개발자 선호)
- 한국어 대화, 기술 용어는 영어 유지(Delegation, Filter, Patch 등)
- 코드 블록 앞 `=` 미사용 (복사 후 바로 붙여넣기)
- 코드 제공 후 적용 위치 명시: 컨트롤 / 속성 / 화면 + 한 줄 요약
- 속성값은 한 줄씩 (X=465/Y=124 함축 표기 금지)
- UI 작업은 STEP별로: 적용 → 스크린샷 확인 → 다음 단계
- 코드가 꼬이면 전체 코드를 받아 통짜로 다시 제공
- Delegation·성능 경고는 항상 선제적으로
- 더 나은 구조가 있으면 코드 전에 먼저 제안
