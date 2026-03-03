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
      ├─ 컬럼 탭 + PageView
      ├─ 컬럼 관리 시트
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
  - WS 이벤트 디스패치
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
- `lib/view/board_detail/board_detail_columns_manage.dart`
  - 컬럼 추가/수정/삭제/이동 시트
  - `_toggleDone` 포함(현재 미노출, 향후 사용 예정)
- `lib/view/board_detail/board_detail_columns_column_view.dart`
  - 단일 컬럼 카드 목록
  - DnD 재정렬/ACK 재시도/롤백
  - 카드 추가 시트

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
├─ WS 동기화 브리지
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

## 8) 유지보수 규칙(권장)

- 화면 엔트리(`*screen.dart`)는 "조립" 중심으로 유지한다.
- 실제 기능은 하위 기능 파일로 분리한다.
- 시트/다이얼로그는 "기능 가까운 파일"에 둔다.
- 상태 동기화(WS/provider 반영)는 UI 파일과 분리한다.
- 새로운 라우트 추가 시 이 문서의 1), 2), 5), 6) 섹션을 함께 갱신한다.

