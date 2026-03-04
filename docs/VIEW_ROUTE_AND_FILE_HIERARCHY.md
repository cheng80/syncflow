# SyncFlow View Route & File Hierarchy

이 문서는 **화면 라우트 흐름**과 **파일 책임 경계**를 한 번에 파악하기 위한 구조 문서입니다.
목표는 "어디서 시작해서 어느 파일을 보면 되는지"를 빠르게 추적하는 것입니다.

## 1) 앱 진입 라우트

```text
main.dart
└─ MaterialApp.home
   └─ sessionNotifierProvider 상태 분기
      ├─ 로그인 안됨: LoginScreen
      └─ 로그인 됨: MainScaffold
```

핵심 파일:
- `lib/main.dart`
- `lib/view/auth/login_screen.dart`
- `lib/view/main_scaffold.dart`

## 2) 1차 화면 하이라키 (사용자 관점)

```text
MainScaffold
├─ AppBar (메뉴/타이틀)
├─ Drawer: AppDrawer
└─ Body: BoardListScreen
   └─ 보드 카드 탭
      └─ BoardDetailScreen(푸시 이동)
```

핵심 파일:
- `lib/view/main_scaffold.dart`
- `lib/view/app_drawer.dart`
- `lib/view/board_list_screen.dart`
- `lib/view/board_detail_screen.dart`

## 3) 보드 상세 화면 내부 하이라키

`BoardDetailScreen`은 "조립(오케스트레이션)" 역할만 담당하고, 실제 기능은 part 파일로 분리되어 있습니다.

```text
board_detail_screen.dart
├─ 헤더 조립
│  └─ BoardDetailHeader(widget)
├─ 액션 조립
│  ├─ _BoardMenuButton
│  ├─ _InviteButton
│  └─ _PresenceAvatarsButton / _WsConnectionIndicator
├─ 동기화 브리지
│  └─ _BoardWsBridge
└─ 본문 컬럼 영역
   └─ _BoardColumnsView
      ├─ BoardDetailColumnTabsBar
      │  ├─ 1행: 컬럼 탭 + 컬럼 관리 버튼
      │  └─ 2행: 필터(맨션만 보기, 전체, 완료, 미완료) Container + 가로 스크롤
      ├─ PageView (컬럼별 카드 목록)
      ├─ 컬럼 관리 시트 (_ColumnManageSheet)
      └─ 단일 컬럼 카드뷰 + 재정렬 + 카드추가
```

## 4) 보드 상세 파일 책임 분리

### 4-1) 엔트리
- `lib/view/board_detail_screen.dart`
  - 화면 엔트리
  - 상단/본문 조립
  - 로딩/에러/데이터 분기

### 4-2) 동기화(WS)
- `lib/view/board_detail/board_detail_screen_ws.dart`
  - 보드 룸 join/leave
  - WS 이벤트 디스패치 (BOARD_UPDATED, CARD_*, PRESENCE_*, LOCK_* 등)
  - 보드 캐시/낙관적 상태 반영

### 4-3) 헤더 액션
- `lib/view/board_detail/board_detail_actions_menu.dart`
  - 보드 이름 변경/삭제
- `lib/view/board_detail/board_detail_actions_invite.dart`
  - 초대 코드 생성/복사/공유 시트
- `lib/view/board_detail/board_detail_actions_presence.dart`
  - 연결 상태 점, 접속자 아바타/목록 시트

### 4-4) 컬럼/카드 본문
- `lib/view/board_detail/board_detail_columns_pager.dart`
  - 컬럼 탭 + PageView 컨테이너
  - 필터 행: 맨션만 보기, 전체/완료/미완료 (_StatusFilter, _applyStatusFilter, _buildFilterRow)
- `lib/widget/board_detail_header.dart` (BoardDetailColumnTabsBar)
  - filterRow: 하단 필터만 Container로 감싸고 가로 스크롤
- `lib/view/board_detail/board_detail_columns_manage.dart`
  - 컬럼 추가/수정/삭제/이동 시트
  - `_toggleDone` 포함(현재 미노출, 향후 사용 예정)
- `lib/view/board_detail/board_detail_columns_column_view.dart`
  - 단일 컬럼 카드 목록
  - DnD 재정렬/ACK 재시도/롤백 (완료 카드도 이동 가능)
  - 카드 추가 시트

### 4-5) VM/상태 (board_detail 관련)
- `lib/vm/board_detail_notifier.dart`
  - boardDetailProvider, boardDetailCacheProvider, boardVersionProvider
  - boardTitleOverrideProvider: BOARD_UPDATED WebSocket 시 보드 제목 실시간 반영
  - optimisticCardMovesProvider, cardLocksProvider, presenceMembersProvider
- `lib/widget/card_tile.dart`
  - 완료 카드(status=done)도 이동 아이콘 표시, 컬럼 간 이동 가능
- `lib/widget/card_detail_modal.dart`
  - 상단: 저장/삭제 버튼 (제목 옆), 하단: 저장/삭제 (오른쪽 정렬)
  - 완료됨 줄: 체크박스 + 도움말 아이콘

## 5) 화면 이동/전환 규칙

네비게이션 유틸:
- `lib/navigation/custom_navigation_util.dart`

실제 주요 이동:
- `BoardListScreen -> BoardDetailScreen`
  - `CustomNavigationUtil.to(context, BoardDetailScreen(...))`
- 시트/다이얼로그 닫기
  - `Navigator.pop(...)` 또는 `CustomNavigationUtil.back(...)`

참고:
- 대부분의 세부 편집 동작은 "새 route"가 아니라 **BottomSheet/Dialog**로 처리됩니다.

## 6) 화면별 진입점 요약

```text
LoginScreen
└─ 이메일 인증코드 발송/검증 후 세션 확정

MainScaffold
├─ 튜토리얼 Showcase 등록/재시작
├─ AppDrawer 연결
└─ BoardListScreen 연결

BoardListScreen
├─ 보드 생성/참가 시트
├─ 내보드/참여보드/전체 필터
└─ 보드 탭 시 BoardDetailScreen 이동

BoardDetailScreen
├─ 헤더(메뉴/초대/접속자)
├─ WS 동기화 브리지 (BOARD_UPDATED → 보드 제목 실시간 반영)
├─ 컬럼 탭 + 필터(맨션만 보기, 전체/완료/미완료)
└─ 컬럼/카드 작업(관리/정렬/추가/상세)
```

## 7) 구조 추적 추천 순서

신규 개발자 기준으로 아래 순서로 보면 전체 흐름을 가장 빨리 이해할 수 있습니다.

1. `lib/main.dart`
2. `lib/view/main_scaffold.dart`
3. `lib/view/board_list_screen.dart`
4. `lib/view/board_detail_screen.dart`
5. `lib/view/board_detail/board_detail_columns_pager.dart`
6. `lib/view/board_detail/board_detail_columns_column_view.dart`
7. `lib/view/board_detail/board_detail_screen_ws.dart`
8. `lib/view/board_detail/board_detail_actions_*.dart`

## 8) 유지보수 규칙(상세)

### 8-1) 파일 책임 경계 규칙

- `*screen.dart`(엔트리)는 조립/분기만 담당한다.
  - 허용: provider watch, 로딩/에러 분기, 상단/본문 조립
  - 비허용: 대규모 비즈니스 로직, WS 이벤트 세부 처리, API 직접 호출의 확산
- 기능 파일은 목적별로 분리한다.
  - 액션: `board_detail_actions_*.dart`
  - 동기화: `board_detail_screen_ws.dart`
  - 본문 렌더링/상호작용: `board_detail_columns_*.dart`
- 공통 위젯은 `lib/widget`으로 올리고, 화면 종속 위젯은 `lib/view/...`에 둔다.
- 서버 통신은 `handler/service` 레이어를 통하게 유지한다.
  - UI -> `vm/*_handler.dart` -> `service/api_client.dart`
  - UI 파일에서 API endpoint 문자열 직접 작성 금지

### 8-2) 분리(Extract) 규칙

- 아래 조건 중 2개 이상이면 파일 분리를 우선 검토한다.
  - 파일 길이 400~500줄 이상
  - 상태 변수/메서드가 한 화면 내 2개 이상 독립 기능군을 가짐
  - 특정 기능 수정 시 관련 없는 코드까지 자주 건드리게 됨
- 분리 단위는 "기능 흐름 단위"로 자른다.
  - 예: 초대, 접속자, WS 브리지, 컬럼 관리, 카드 정렬
- 분리 시 외부 계약(파라미터/콜백)은 최소화한다.
  - 가능하면 `required`로 명시하고, nullable 의존을 줄인다.
- 분리 후에도 엔트리 파일에서 “화면 읽기 순서”가 유지되어야 한다.
  - 상단(헤더) -> 동기화 -> 본문 순으로 조립

### 8-3) 마이그레이션(구조 변경) 규칙

- 1단계: 호환 레이어 먼저 추가
  - 기존 호출 경로를 즉시 제거하지 말고 fallback 유지
  - 예: 저장형 데이터 도입 시 파싱 fallback 유지
- 2단계: 신규 경로를 기본값으로 전환
  - 신규 provider/응답 필드를 UI가 우선 사용
- 3단계: 회귀 검증 후 레거시 제거
  - 제거 전 `todo.md`에 제거 조건/검증 항목 명시
- 4단계: 문서 동기화
  - 이 문서 + `todo.md` + 관련 가이드 문서를 같은 PR에서 갱신

### 8-4) 라우트/화면 추가 규칙

- 새 라우트 추가 시 반드시 함께 수정:
  - 본 문서 `1) 앱 진입 라우트`, `2) 1차 화면 하이라키`, `5) 화면 이동 규칙`, `6) 진입점 요약`
- Push/딥링크 진입점이 생기면, "진입 파라미터와 실패 fallback"을 문서에 명시
- 새 화면에서 사용하는 sheet/dialog가 있으면 “route 기반인지 sheet 기반인지”를 명확히 기록

### 8-5) 상태/동기화 규칙

- WS 이벤트 적용 로직은 한 곳(`board_detail_screen_ws.dart`)으로 모은다.
- UI 렌더링 파일은 이벤트 타입 분기/파싱 코드를 직접 갖지 않는다.
- 낙관적 업데이트는 다음 3가지를 항상 포함한다.
  - 적용(optimistic set)
  - 확정(ACK/최신 버전 반영)
  - 실패 롤백(에러/타임아웃)
- 버전/타임스탬프 기반 구이벤트 무시 규칙을 유지한다.

### 8-6) 네이밍/배치 규칙

- 파일명은 기능 우선 + 화면 컨텍스트 유지:
  - `board_detail_<domain>_<feature>.dart`
- private 위젯/헬퍼 접두사 `_` 유지
- WS 이벤트 핸들 메서드는 `_apply<Event>` 네이밍 통일
- `part` 분리 파일은 반드시 상위 `board_detail_screen.dart` 기준으로만 사용

### 8-7) 테스트/검증 규칙

- 구조 변경 PR 최소 검증:
  - `flutter analyze`
  - 서버 스키마/컴파일 검증 (`python -m compileall fastapi/app`)
  - 핵심 사용자 흐름 수동 확인(로그인 -> 보드목록 -> 보드상세 -> 카드수정)
- 동기화 변경 시 멀티클라이언트 시나리오 1개 이상 확인
  - 예: 한 클라 수정 -> 다른 클라 즉시 반영

### 8-8) 변경 체크리스트(실무용)

1. 변경 기능이 어떤 책임 레이어에 속하는지 먼저 결정했는가? (view/vm/service/server)
2. 엔트리 파일에 비즈니스 로직이 새로 들어가지 않았는가?
3. fallback(호환성) 계획을 먼저 넣었는가?
4. `todo.md` 항목 상태를 코드 변경과 함께 갱신했는가?
5. 이 문서의 하이라키/라우트 섹션을 최신화했는가?
