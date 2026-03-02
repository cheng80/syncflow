# SyncFlow

소규모 팀을 위한 실시간 경량 협업 칸반 보드 앱.

> **구현 계획**: [docs/PLAN_BASIC_STRUCTURE.md](docs/PLAN_BASIC_STRUCTURE.md)  
> **코딩 규칙**: [CURSOR.md](CURSOR.md)

---

## 제품 정의

| 항목 | 내용 |
|------|------|
| **한 줄 정의** | 소규모 팀을 위한 실시간 경량 협업 칸반 보드 앱 |
| **대상** | 2~5인 소규모 팀 (콘텐츠 제작, 스터디, 해커톤 등) |
| **핵심 가치** | 실시간 동기화, 템플릿 기반 빠른 시작, 미니멀 UX, 안정적 협업 |

---

## 주요 기능 (MVP)

| 기능 | 설명 |
|------|------|
| 계정·인증 | 이메일 6자리 코드 → UUID4 세션 토큰 (14일) |
| 보드 | 생성(템플릿 선택), 수정, 삭제(owner만) |
| 컬럼 | 추가, 이름 수정, 삭제, 순서 변경 |
| 카드 | 생성, 제목/설명 수정, 드래그 이동, 우선순위·담당자·마감일 |
| 실시간 동기화 | WebSocket 기반 카드 이동/수정 즉시 반영 |
| Soft Lock | 카드 편집 중 동시 편집 방지 (TTL 30초) |
| Presence | 보드 접속 사용자 아바타 표시 |

---

## 기술 스택

| 구분 | 기술 | 용도 |
|------|------|------|
| 프론트엔드 | Flutter | iOS/Android/Web |
| 상태 관리 | Riverpod 3.0+ | Provider/Notifier 직접 구현 (코드 제너레이터 미사용) |
| 백엔드 | FastAPI | REST API, WebSocket |
| DB | MySQL | users, sessions, boards, columns, cards |
| 설정 | GetStorage | 세션 토큰, 테마 등 |
| UI | Neo-Brutalism | 강한 대비, 두꺼운 보더, 오프셋 쉐도우 |

---

## 아키텍처

**MVVM + Handler/Notifier**

```
lib/
├── main.dart
├── model/       # Board, Card, Column, User
├── view/        # 화면 (auth, board_list, board_detail)
├── vm/          # Handler(DB/API), Notifier(Riverpod)
├── service/     # api_client, ws_service
├── widget/      # card_tile, column_header, presence_avatars
├── theme/
└── util/
```

```
fastapi/app/
├── main.py
├── api/         # auth, boards, cards
├── ws/          # WebSocket (connection, room, presence, lock)
├── database/
└── utils/
```

- **Handler**: DB/API 접근 전담
- **Notifier**: Riverpod 상태 관리
- **View**: UI만, `ref.watch`/`ref.read`로 상태 구독·액션 호출

---

## 구현 단계 (Phase)

| Phase | 내용 |
|-------|------|
| **0** | 기존 코드 제거, 프로젝트 초기 설정 |
| **1** | 계정 및 인증 |
| **2** | 보드 목록 및 생성 |
| **3** | 보드 상세 및 카드 CRUD |
| **4** | WebSocket 실시간 동기화 |
| **5** | Soft Lock 및 Owner Lock |
| **6** | 2차 확장 (멤버 초대, 컬럼 편집 등) |

상세: [docs/PLAN_BASIC_STRUCTURE.md](docs/PLAN_BASIC_STRUCTURE.md)

---

## 실행

```bash
flutter pub get
flutter run
```

**우선 기기**: iOS 시뮬레이터 (Debug 모드)
