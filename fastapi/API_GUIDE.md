# SyncFlow FastAPI 서버

실시간 경량 협업 칸반 보드(SyncFlow) 백엔드 API 서버입니다. REST API + WebSocket으로 실시간 동기화를 지원합니다.

## 프로젝트 구조

```
fastapi/
├── app/
│   ├── api/                  # REST API 라우터
│   │   ├── auth.py           # 인증 (이메일 코드, 세션, 로그아웃, 탈퇴)
│   │   ├── boards.py         # 보드 CRUD, 컬럼, 초대
│   │   └── cards.py          # 카드 CRUD, 아카이브
│   ├── database/
│   │   └── connection.py     # MySQL 연결
│   ├── utils/
│   │   ├── auth_deps.py      # X-Session-Token 인증 의존성
│   │   └── email_service.py  # 이메일 인증 코드 발송
│   ├── ws/                   # WebSocket
│   │   ├── connection.py     # WS 엔드포인트, 토큰 인증
│   │   ├── handlers.py       # 메시지 핸들러 (보드 참가, 카드 이동 등)
│   │   ├── room.py           # 보드별 룸 관리, 브로드캐스트
│   │   └── lock.py          # 카드 편집 락
│   └── main.py               # FastAPI 진입점
├── mysql/
│   └── init_schema.sql       # DB 초기화 스키마
├── scripts/
│   ├── init_db.py            # DB 초기화 스크립트
│   └── verify_schema.py      # 스키마 검증
├── requirements.txt
└── API_GUIDE.md              # 이 파일
```

## 설치 및 실행

### 1. 가상 환경 생성 및 활성화

```bash
cd fastapi
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

### 2. 의존성 설치

```bash
pip install -r requirements.txt
```

### 3. 환경 변수 설정

`.env.example`을 참고하여 `.env` 파일을 생성합니다.

```bash
cp .env.example .env
# .env 편집: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, SMTP_* 등
```

FCM 서버 발송까지 사용할 경우 아래도 추가 설정합니다.

```bash
FCM_PUSH_ENABLED=true
FCM_DRY_RUN=false
FIREBASE_ADMIN_CREDENTIALS=./secure/serviceAccountKey.json
FIREBASE_PROJECT_ID=<firebase-project-id> # 선택
```

### 4. 데이터베이스 초기화

```bash
mysql -u root -p < mysql/init_schema.sql
# 또는 scripts/init_db.py 실행
```

### 5. 서버 실행

```bash
cd fastapi
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 6. API 문서

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

---

## 인증

대부분의 API는 `X-Session-Token` 헤더가 필요합니다.

1. `POST /v1/auth/send-code` — 이메일로 6자리 코드 발송
2. `POST /v1/auth/verify` — 코드 검증 후 `session_token` 반환
3. 이후 요청 시 `X-Session-Token: <session_token>` 헤더 추가

WebSocket은 `wss://host/ws?token=<session_token>` 형태로 연결합니다.

---

## 엔드포인트

### 기본

| Method | Path | 설명 |
|--------|------|------|
| GET | `/` | API 정보 |
| GET | `/health` | 헬스 체크 |

### Auth (`/v1/auth`)

| Method | Path | 인증 | 설명 |
|--------|------|------|------|
| POST | `/send-code` | - | 이메일로 6자리 인증 코드 발송 |
| POST | `/verify` | - | 코드 검증 → session_token 반환 |
| GET | `/me` | O | 현재 사용자 정보 |
| POST | `/logout` | - | 세션 폐기 |
| DELETE | `/me` | O | 회원 탈퇴 |

### Boards (`/v1/boards`)

| Method | Path | 인증 | 설명 |
|--------|------|------|------|
| GET | `` | O | 내 보드 목록 |
| POST | `` | O | 보드 생성 (template: todo/simple) |
| GET | `/{board_id}` | O | 보드 상세 (컬럼+카드) |
| PATCH | `/{board_id}` | O | 보드 제목 수정 (owner) |
| DELETE | `/{board_id}` | O | 보드 삭제 (owner) |
| POST | `/join` | O | 초대 코드로 보드 참가 |
| POST | `/{board_id}/invite` | O | 초대 코드 생성 (owner) |
| POST | `/{board_id}/columns` | O | 컬럼 추가 (owner) |
| PATCH | `/{board_id}/columns/{column_id}` | O | 컬럼 수정 (owner) |
| DELETE | `/{board_id}/columns/{column_id}` | O | 컬럼 삭제 (owner) |

### Cards (`/v1/cards`)

| Method | Path | 인증 | 설명 |
|--------|------|------|------|
| POST | `` | O | 카드 생성 |
| PATCH | `/{card_id}` | O | 카드 수정 |
| DELETE | `/{card_id}` | O | 카드 아카이브 |

#### 카드 이벤트 기반 푸시(서버 발송)

- 카드 생성/수정 시 신규 멘션 대상에게 FCM 발송
- 카드 수정 시 `assignee_id` 변경되면 신규 담당자에게 FCM 발송
- `push_tokens.is_active=TRUE`인 iOS/Android 토큰으로만 발송

### WebSocket

| Path | 설명 |
|------|------|
| `GET /ws?token=<session_token>` | 실시간 동기화 연결 |

---

## API 상세

### POST /v1/auth/send-code

**Request:**
```json
{ "email": "user@example.com" }
```

**Response:**
```json
{ "ok": true, "message": "인증 코드가 발송되었습니다." }
```

### POST /v1/auth/verify

**Request:**
```json
{ "email": "user@example.com", "code": "123456" }
```

**Response:**
```json
{
  "session_token": "uuid-...",
  "expires_at": "2025-03-16T12:00:00Z",
  "user_id": 1
}
```

### POST /v1/boards (보드 생성)

**Request:**
```json
{ "title": "내 보드", "template": "todo" }
```

`template`: `"todo"` (할 일/진행 중/완료) 또는 `"simple"` (단일 컬럼)

### POST /v1/boards/join (초대 코드로 참가)

**Request:**
```json
{ "code": "ABC123" }
```

### POST /v1/cards (카드 생성)

**Request:**
```json
{
  "title": "카드 제목",
  "description": "설명 (선택)",
  "column_id": 1,
  "priority": "medium"
}
```

---

## 데이터베이스

### 연결 설정

`app/database/connection.py`는 환경변수를 사용합니다.

| 변수 | 기본값 |
|------|--------|
| DB_HOST | 127.0.0.1 |
| DB_USER | root |
| DB_PASSWORD | (빈 문자열) |
| DB_NAME | syncflow_db |
| DB_PORT | 3306 |

### 주요 테이블

| 테이블 | 설명 |
|--------|------|
| users | 이메일 계정 |
| email_verifications | 이메일 6자리 인증 코드 |
| sessions | 세션 토큰 (14일) |
| boards | 보드 |
| board_members | 보드 참여자 |
| board_invites | 초대 코드 |
| columns | 컬럼 |
| cards | 카드 |

---

## 이메일 설정 (인증 코드 발송)

`app/utils/email_service.py`에서 SMTP 설정을 사용합니다.

| 변수 | 설명 |
|------|------|
| SMTP_HOST | smtp.gmail.com 등 |
| SMTP_PORT | 587 |
| SMTP_USER, SMTP_PASSWORD | Gmail 앱 비밀번호 등 |
| FROM_EMAIL, FROM_NAME | 발신자 |

---

## CORS

개발 환경에서는 `allow_origins=["*"]`로 설정되어 있습니다. 프로덕션에서는 Flutter 앱 도메인으로 제한하세요.
