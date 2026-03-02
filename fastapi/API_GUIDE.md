# Habit App FastAPI 서버

습관 앱(HabitCell) 백업/복구를 위한 FastAPI 백엔드 서버입니다. Local-first + Snapshot Backup 방식으로 동작합니다.

## 프로젝트 구조

```
fastapi/
├── app/
│   ├── api/                  # API 엔드포인트 라우터
│   │   ├── __init__.py
│   │   ├── backups.py         # 백업 API (업로드, 최신 조회)
│   │   └── recovery.py       # 복구 API (이메일 인증, 백업 조회)
│   ├── database/              # 데이터베이스 연결 설정
│   │   ├── __init__.py
│   │   ├── connection.py     # 운영용 DB 연결
│   │   └── connection_local.py  # 로컬 개발용 DB 연결
│   ├── utils/                 # 유틸리티
│   │   └── email_service.py  # 이메일 인증 코드 발송 (복구용)
│   └── main.py                # FastAPI 애플리케이션 진입점
├── mysql/
│   └── init_schema.sql        # 데이터베이스 초기화 스키마 (DDL)
├── requirements.txt           # Python 의존성
└── API_GUIDE.md               # 이 파일
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

### 3. 데이터베이스 초기화

```bash
mysql -u your_user -p < mysql/init_schema.sql
```

### 4. 서버 실행

```bash
# fastapi 디렉터리에서 실행 (필수)
cd fastapi
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 또는 main.py 직접 실행
python app/main.py
```

### 5. API 문서 확인

서버 실행 후 다음 URL에서 API 문서를 확인할 수 있습니다:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 현재 엔드포인트

### 기본 엔드포인트
- `GET /` - API 정보
- `GET /health` - 헬스 체크

### Backups API (`/v1/backups`)
- `POST /v1/backups` - 백업 업서트 (device_uuid당 최신 1개)
- `GET /v1/backups/latest?device_uuid={uuid}` - 최신 백업 조회

### Recovery API (`/v1/recovery`)
- `GET /v1/recovery/status?device_uuid={uuid}` - 이메일 인증 여부 + 서버 저장 백업 여부 조회
- `POST /v1/recovery/email/request` - 이메일 인증 코드 요청
- `POST /v1/recovery/email/verify` - 이메일 인증 코드 검증
- `GET /v1/recovery/backup?device_uuid={uuid}` - 다른 기기 복구용 백업 조회 (이메일 인증 필요)

## API 상세

### POST /v1/backups (백업 업로드)

**Request Body (JSON):**
```json
{
  "device_uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "exported_at": "2025-02-16T12:00:00Z",
  "habits": [...],
  "categories": [...],
  ...
}
```

- `device_uuid`: 필수. 기기 고유 식별자
- `exported_at`: ISO8601 형식 (선택)
- 나머지: Flutter 앱에서 export한 JSON 스냅샷 전체

**Response:**
```json
{
  "status": "ok",
  "device_uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### GET /v1/backups/latest (최신 백업 조회)

**Query:** `device_uuid` (필수)

**Response:**
```json
{
  "payload": { "device_uuid": "...", "habits": [...], ... },
  "checksum": "sha256...",
  "payload_updated_at": "2025-02-16 12:00:00"
}
```

### GET /v1/recovery/status (복구 상태 조회)

**Query:** `device_uuid` (필수)

**Response:**
```json
{
  "email_verified": true,
  "email": "user@example.com",
  "has_backup": true,
  "last_backup_at": "2025-02-16T12:00:00"
}
```

### POST /v1/recovery/email/request (인증 코드 요청)

**Request Body:**
```json
{
  "device_uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "status": "ok",
  "message": "인증 코드가 발송되었습니다."
}
```

### POST /v1/recovery/email/verify (인증 코드 검증)

**Request Body:**
```json
{
  "device_uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "email": "user@example.com",
  "code": "123456"
}
```

**Response:**
```json
{
  "status": "ok",
  "message": "이메일이 등록되었습니다."
}
```

### GET /v1/recovery/backup (다른 기기 복구용 백업 조회)

**Query:** `device_uuid` (필수)

- 이메일 인증이 완료된 기기만 호출 가능
- 동일 이메일로 인증된 기기들의 백업 중 최신 1개 반환

**Response:**
```json
{
  "payload": { "device_uuid": "...", "habits": [...], ... },
  "checksum": "sha256...",
  "payload_updated_at": "2025-02-16 12:00:00"
}
```

## 데이터베이스 설정

### 1. 연결 설정

`app/database/connection.py`에서 DB 설정을 수정합니다. (환경변수 미사용 시)

```python
DB_CONFIG = {
    'host': 'your_host',
    'user': 'your_user',
    'password': 'your_password',
    'database': 'habitcell_db',
    'charset': 'utf8mb4',
    'port': 3306
}
```

로컬 개발 시 `connection_local.py`를 참고하여 `connection.py`를 교체하거나, 환경변수로 분기할 수 있습니다.

### 2. 스키마

`mysql/init_schema.sql` 실행 시 다음 테이블이 생성됩니다:

| 테이블 | 설명 |
|--------|------|
| `devices` | 기기 등록 (device_uuid, email, email_verified_at) |
| `email_verifications` | 이메일 6자리 인증 코드 (만료 10분, 최대 5회 시도) |
| `backups` | SQLite 스냅샷 JSON (device당 최신 1개) |

## 이메일 인증 (복구용)

- `app/utils/email_service.py`에서 이메일 발송 로직 관리
- 환경변수: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `FROM_NAME`
- Gmail 사용 시 앱 비밀번호 필요
- 인증 코드: 6자리 숫자, 10분 유효, 최대 5회 시도

## CORS 설정

현재 모든 origin을 허용하도록 설정되어 있습니다. 프로덕션 환경에서는 Flutter 앱 도메인으로 제한하세요.

```python
# app/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-app-domain.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 엔드포인트 추가 방법

### 1. 라우터 파일 생성

`app/api/` 폴더에 새 라우터 파일을 생성합니다.

### 2. main.py에 라우터 등록

```python
from app.api import your_router
app.include_router(your_router.router, prefix="/v1/your-path", tags=["your-tag"])
```

### 3. 데이터베이스 사용

```python
from app.database.connection import connect_db

conn = connect_db()
try:
    cursor = conn.cursor()
    cursor.execute("SELECT ...")
    results = cursor.fetchall()
    return {"data": results}
finally:
    conn.close()
```

## 참고사항

- API 문서는 자동 생성됩니다 (Swagger UI: `/docs`, ReDoc: `/redoc`)
- MySQL 8.0 사용, UTF-8 인코딩(utf8mb4)
- 백업 payload는 SHA256 checksum으로 무결성 검증 가능
