# SyncFlow 기본 구현 계획

> **기준 규칙**: [CURSOR.md](../CURSOR.md)  
> **참조 문서**: [docs/syncflow/](syncflow/), [docs/email/](email/)  
> **유지**: 구현 시마다 해당 항목 `[ ]` → `[x]`로 갱신

---

## 1. 제품 정의 요약

| 항목 | 내용 |
|------|------|
| **한 줄 정의** | 소규모 팀을 위한 실시간 경량 협업 칸반 보드 앱 |
| **대상** | 2~5인 소규모 팀 (콘텐츠 제작, 스터디, 해커톤 등) |
| **핵심 가치** | 실시간 동기화, 템플릿 기반 빠른 시작, 미니멀 UX, 안정적 협업 |

---

## 2. 구축 범위 (docs/syncflow 기준)

| 영역 | 내용 |
|------|------|
| **Flutter** | 보드/카드/컬럼 UI, WebSocket 실시간 동기화, Neo-Brutalism 디자인 |
| **FastAPI** | users/sessions/boards/columns/cards, WebSocket 서버 (기존 폴더 구조 유지) |
| **인증** | 이메일 6자리 코드 → UUID4 세션 토큰 (14일) |
| **DB** | MySQL (ERD v1 기준) |

---

## 3. 구현 단계 (Phase)

### Phase 0: 기존 코드 제거 및 프로젝트 초기 설정
- [x] Flutter: habit/picklet 관련 코드 제거 (habit_db_schema, habit 관련 view/vm 등)
- [x] FastAPI: 기존 백업/복구 API 제거, habitcell_db 참조 제거
- [x] MySQL: syncflow_db 생성, ERD 기준 스키마 적용
- [x] FastAPI: SyncFlow 앱 구조 (app/, api/, database/, utils/ 유지)
- [x] Flutter: SyncFlow 전용 lib 구조 (model, vm, view, service, widget)

### Phase 1: 계정 및 인증
**목표**: 로그인/로그아웃 가능한 최소 인증

- [x] 1.1 MySQL 스키마: users, sessions (init_schema.sql)
- [x] 1.2 REST API: 이메일 코드 발송, 코드 검증 → 세션 생성 (fastapi/app/api/auth.py)
- [x] 1.3 Flutter: 로그인 화면 (이메일 입력 → 코드 입력 → 로그인) (lib/view/auth/)
- [x] 1.4 Flutter: 세션 저장/복원 (Secure Storage), 자동 로그인 (lib/vm/, lib/util/)
- [x] 1.5 Flutter: 로그아웃 (lib/vm/session_notifier.dart)

**참조**: 제품기획서 3.1, ERD users/sessions, [docs/email/](email/)

### Phase 2: 보드 목록 및 생성
**목표**: 로그인 후 보드 목록 조회, 새 보드 생성

- [x] 2.1 MySQL 스키마: boards, board_members, columns, cards (init_schema.sql)
- [x] 2.2 REST API: 보드 목록, 보드 생성 (템플릿 선택) (fastapi/app/api/boards.py)
- [x] 2.3 Flutter: 보드 목록 화면 (대시보드) (lib/view/board_list_screen.dart)
- [x] 2.4 Flutter: 템플릿 선택 → 보드 생성 플로우 (lib/view/, lib/vm/)
- [x] 2.5 Flutter: BoardListNotifier (Riverpod) (lib/vm/board_list_notifier.dart)

**참조**: 제품기획서 3.2~3.4, ERD boards/columns

### Phase 3: 보드 상세 및 카드 CRUD
**목표**: 보드 진입 후 컬럼/카드 표시, 카드 생성/수정/이동

- [x] 3.1 REST API: 보드 상세(컬럼+카드), 카드 CRUD (fastapi/app/api/)
- [x] 3.2 Flutter: 보드 상세 화면 (PageView 1컬럼, 세로 스크롤) (lib/view/board_detail_screen.dart)
- [x] 3.3 Flutter: 카드 위젯, 카드 상세 모달 (lib/view/, lib/widget/)
- [x] 3.4 Flutter: BoardDetailHandler, CardHandler (DB/API 접근) (lib/vm/)
- [x] 3.5 Flutter: 카드 드래그 재정렬 (같은 컬럼 내) (lib/view/)

**참조**: UI/UX 설계서, ERD cards

### Phase 4: WebSocket 실시간 동기화
**목표**: 카드 이동/수정이 다른 클라이언트에 실시간 반영

- [x] 4.1 FastAPI: WebSocket 엔드포인트, 세션 토큰 검증 (fastapi/app/ws/)
- [x] 4.2 FastAPI: JOIN_BOARD, LEAVE_BOARD, 룸 브로드캐스트 (fastapi/app/ws/)
- [x] 4.3 FastAPI: CARD_CREATE/MOVE/UPDATE 이벤트 처리 (fastapi/app/ws/)
- [x] 4.4 Flutter: WebSocket 연결/재연결, JOIN_BOARD (lib/service/ws_service.dart)
- [x] 4.5 Flutter: 이벤트 수신 → Riverpod 상태 반영 (optimistic update) (lib/vm/)
- [x] 4.6 Flutter: Presence UI (접속자 아바타) (lib/view/)

**참조**: WebSocket 이벤트 스펙 v1

### Phase 5: Soft Lock 및 Owner Lock
**목표**: 카드 편집 충돌 방지, Owner Lock 지원

- [x] 5.1 FastAPI: Soft lock 메모리 저장, TTL 30초, RENEW/RELEASE (fastapi/app/ws/)
- [x] 5.2 FastAPI: LOCK_ACQUIRE/RENEW/RELEASE, CARD_LOCKED/UNLOCKED (fastapi/app/ws/)
- [x] 5.3 Flutter: 카드 상세 진입 시 LOCK_ACQUIRE, 저장/취소 시 RELEASE (lib/vm/, lib/view/)
- [x] 5.4 Flutter: 잠긴 카드 읽기 전용, "OO님이 편집 중" 표시 (lib/view/)
- [ ] 5.5 (옵션) Owner Lock: owner_lock 필드, CARD_OWNER_LOCK_SET (ERD 반영)

**참조**: WebSocket 스펙 6절, 7.0.2

### Phase 6: 2차 확장 (MVP 이후)

- [x] 6.1 멤버 초대 (board_invites, 초대 코드)
- [x] 6.2 컬럼 추가/수정/삭제/재정렬
- [x] 6.3 Markdown 확장 (체크리스트, @멘션)

---

## 4. 폴더 구조 (Flutter)

```
lib/
├── main.dart
├── db/                    # 로컬 DB (필요 시)
├── model/                 # 도메인 모델 (Board, Card, Column, User)
├── vm/                    # ViewModel (Notifier, Handler)
│   ├── session_notifier.dart
│   ├── board_list_notifier.dart
│   ├── board_detail_notifier.dart
│   ├── board_handler.dart
│   └── card_handler.dart
├── service/               # API, WebSocket
│   ├── api_client.dart
│   └── ws_service.dart
├── view/                  # 화면
│   ├── auth/
│   │   └── login_screen.dart
│   ├── board_list_screen.dart
│   ├── board_detail_screen.dart
│   └── ...
├── widget/                # 재사용 위젯
│   ├── card_tile.dart
│   ├── column_header.dart
│   └── presence_avatars.dart
├── theme/
└── util/
```

---

## 5. 폴더 구조 (FastAPI)

> 기존 `app/`, `api/`, `database/`, `utils/` 구조 유지

```
fastapi/app/
├── main.py
├── api/
│   ├── auth.py           # 이메일 인증, 세션
│   ├── boards.py         # 보드 CRUD
│   └── cards.py          # 카드 CRUD (REST, 초기 로드용)
├── ws/                   # 신규
│   ├── connection.py     # WebSocket 연결, 인증
│   ├── room.py           # 룸/브로드캐스트
│   ├── presence.py       # 온라인 사용자
│   ├── lock.py           # Soft lock
│   └── handlers.py       # CARD_*, JOIN_*, LOCK_* 처리
├── database/
└── utils/
```

---

## 6. Riverpod 및 네이밍 규칙 (CURSOR.md 준수)

**Riverpod**: 3.0+ 문법, 코드 제너레이터 미사용, Provider/Notifier 직접 구현

| 용도 | 규칙 | 예시 |
|------|------|------|
| DB/저장소 접근 | Handler | BoardHandler, CardHandler |
| Riverpod 상태 | Notifier | BoardListNotifier, SessionNotifier |
| Repository | 사용 안 함 | (Git 혼동 방지) |

---

## 7. UI/UX 가이드 (Neo-Brutalism)

- 강한 대비, 두꺼운 보더(2~3px)
- 오프셋 쉐도우, 둥글지 않은 카드(또는 6~8px)
- Row/Column: `spacing` 파라미터 사용
- 애니메이션: 200ms, 카드 드래그 시 scale 1.03~1.05

---

## 8. 위험 및 고려사항

| 항목 | 내용 |
|------|------|
| **FastAPI** | 단일 인스턴스 전제, Soft lock은 메모리 저장 |
| **재연결** | WebSocket 끊김 시 REST로 스냅샷 재조회 후 WS 이벤트만 수신 |
| **초대** | 1차 MVP에서는 미적용, board_invites는 ERD에만 반영 |

---

## 9. 다음 액션

1. **Phase 1** 진행: 1.2 auth API → 1.3~1.5 Flutter 로그인
2. 각 Phase 시작 전 접근 방식 설명 → 승인 → 코딩 (CURSOR.md 1항)
3. 구현 완료 시 본 문서 해당 항목 체크 `[x]` 갱신

---

*작성일: 2026-03-02 | 최종 갱신: Phase 6.3 완료*
