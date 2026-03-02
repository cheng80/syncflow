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
| 멤버 초대 | 6자리 초대 코드로 보드 참가 |

---

## 기술 스택

| 구분 | 기술 | 용도 |
|------|------|------|
| 프론트엔드 | Flutter | iOS/Android/Web |
| 상태 관리 | Riverpod 3.0+ | Provider/Notifier 직접 구현 |
| 백엔드 | FastAPI | REST API, WebSocket |
| DB | MySQL | users, sessions, boards, columns, cards |
| 설정 | GetStorage, FlutterSecureStorage | 테마 등, 세션 토큰 |
| UI | Neo-Brutalism | 강한 대비, 두꺼운 보더, 오프셋 쉐도우 |

---

## 아키텍처

**MVVM + Handler/Notifier**

```
lib/
├── main.dart
├── model/       # Board, Card, Column, User
├── view/        # auth, board_list, board_detail, main_scaffold, app_drawer
├── vm/          # Handler(API), Notifier(Riverpod)
├── service/     # api_client, ws_service, in_app_review_service
├── widget/      # card_tile, card_detail_modal, column_header, presence_avatars
├── theme/
├── util/
├── navigation/
└── json/
```

```
fastapi/app/
├── main.py
├── api/         # auth, boards, cards
├── ws/          # connection, handlers, room, lock
├── database/
└── utils/
```

- **Handler**: API 접근 전담
- **Notifier**: Riverpod 상태 관리
- **View**: UI만, `ref.watch`/`ref.read`로 상태 구독·액션 호출

---

## 실행

### 1. Flutter 앱

```bash
flutter pub get
flutter run
```

**우선 기기**: iOS 시뮬레이터 (Debug 모드)

### 2. FastAPI 백엔드 (필수)

```bash
cd fastapi
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
# .env 설정 후
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

상세: [fastapi/API_GUIDE.md](fastapi/API_GUIDE.md)

### 3. API Base URL

앱은 기본적으로 `http://127.0.0.1:8000` (iOS) 또는 `http://10.0.2.2:8000` (Android 에뮬레이터)에 연결합니다.

원격 서버 사용 시 `lib/util/common_util.dart`의 `customApiBaseUrl`을 설정하세요.

```dart
const String? customApiBaseUrl = 'http://your-server.com:8000';
```

---

## 구현 단계 (Phase)

| Phase | 내용 | 상태 |
|-------|------|------|
| **0** | 기존 코드 제거, 프로젝트 초기 설정 | 완료 |
| **1** | 계정 및 인증 | 완료 |
| **2** | 보드 목록 및 생성 | 완료 |
| **3** | 보드 상세 및 카드 CRUD | 완료 |
| **4** | WebSocket 실시간 동기화 | 완료 |
| **5** | Soft Lock 및 Owner Lock | 완료 |
| **6** | 멤버 초대, 컬럼 편집 등 | 완료 |

상세: [docs/PLAN_BASIC_STRUCTURE.md](docs/PLAN_BASIC_STRUCTURE.md)

---

## WebSocket 연결 오류 (프록시/리버스 프록시)

`WebSocketException: Connection was not upgraded to websocket` 발생 시:

- **원인**: nginx, QNAP myqnapcloud 등 리버스 프록시가 WebSocket 업그레이드를 거부
- **해결**: 프록시에 WebSocket 업그레이드 설정 추가

**nginx 예시**:
```nginx
location /ws {
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_pass http://127.0.0.1:8000;
}
```

- **임시**: WebSocket 실패 시 앱은 REST만으로 동작 (실시간 동기화 미지원)

---

## 문서

| 문서 | 설명 |
|------|------|
| [docs/PLAN_BASIC_STRUCTURE.md](docs/PLAN_BASIC_STRUCTURE.md) | 구현 계획 |
| [fastapi/API_GUIDE.md](fastapi/API_GUIDE.md) | FastAPI 엔드포인트, 설정 |
| [docs/RELEASE_BUILD.md](docs/RELEASE_BUILD.md) | 릴리즈 빌드 절차 |
| [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) | 앱 스토어 출시 체크리스트 |
| [docs/DRAWER_AND_VERSION_GUIDE.md](docs/DRAWER_AND_VERSION_GUIDE.md) | Drawer, 버전 표시 |
| [docs/TUTORIAL_SHOWCASEVIEW_GUIDE.md](docs/TUTORIAL_SHOWCASEVIEW_GUIDE.md) | 튜토리얼 화면 |
