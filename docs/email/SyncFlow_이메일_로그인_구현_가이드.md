# SyncFlow 이메일 로그인 구현 가이드

SyncFlow 앱의 계정 인증에서 이메일 6자리 코드를 사용하는 구현 방법을 안내합니다.

**대상**: SyncFlow (소규모 팀 협업 칸반 앱)  
**갱신일**: 2026-03-02

---

## 목차

1. [개요](#1-개요)
2. [데이터베이스 설정](#2-데이터베이스-설정)
3. [백엔드 구현](#3-백엔드-구현)
4. [프론트엔드 구현](#4-프론트엔드-구현)
5. [이메일 서비스 설정](#5-이메일-서비스-설정)
6. [권장 구현 순서](#6-권장-구현-순서)
7. [보안 고려사항](#7-보안-고려사항)

---

## 1. 개요

### 목적
- 이메일은 **계정 인증(로그인)** 수단으로 사용
- User 기반 구조: users, sessions 테이블
- 로그인 성공 시 session_token(UUID4) 발급 → API/WebSocket 인증에 사용

### 플로우
1. **코드 발송** → 이메일 입력 후 6자리 코드 발송
2. **코드 검증** → 코드 입력 후 users 생성/조회 → sessions 생성 → session_token 반환
3. **로그인 완료** → session_token을 Secure Storage에 저장 → 앱 사용

---

## 2. 데이터베이스 설정

### 2.1 syncflow_db 스키마

`fastapi/mysql/init_schema.sql` 참고.

#### email_verifications
```sql
CREATE TABLE IF NOT EXISTS email_verifications (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  attempt_count INT NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_expires_at (expires_at)
);
```

#### users
- `email`, `email_verified_at` 컬럼에 인증 완료 후 값 저장
- 인증 성공 시 없으면 생성, 있으면 조회

#### sessions
- `user_id`, `session_token`(UUID4), `expires_at`(14일), `revoked`

---

## 3. 백엔드 구현

### 3.1 API 엔드포인트

**파일**: `fastapi/app/api/auth.py`

#### 3.1.1 인증 코드 발송

```
POST /v1/auth/send-code
Content-Type: application/json
Body: { "email": "user@example.com" }
```

- 6자리 코드 생성 (`secrets.choice`)
- code_hash(SHA256) 저장
- 이메일 발송 (`EmailService.send_login_code`)
- 응답: `{ "ok": true, "message": "인증 코드가 발송되었습니다." }`

#### 3.1.2 인증 코드 검증 → 로그인

```
POST /v1/auth/verify
Content-Type: application/json
Body: { "email": "user@example.com", "code": "123456" }
```

- code_hash 비교, expires_at, attempt_count 확인
- users 생성/조회
- sessions에 session_token(UUID4) INSERT
- 응답: `{ "session_token": "...", "expires_at": "...", "user_id": 1 }`

#### 3.1.3 로그아웃

```
POST /v1/auth/logout
Body: { "session_token": "..." }
```

- sessions.revoked = TRUE

### 3.2 이메일 서비스

`fastapi/app/utils/email_service.py`의 `send_login_code()` 사용:

```python
EmailService.send_login_code(to_email, code, expires_minutes=10)
```

---

## 4. 프론트엔드 구현

### 4.1 로그인 화면

**파일**: `lib/view/auth/login_screen.dart`

1. **Step 1: 이메일 입력**
   - 이메일 입력 필드
   - "인증 코드 받기" 버튼 → `ApiClient().sendAuthCode(email)`

2. **Step 2: 코드 입력**
   - 6자리 숫자 입력 필드
   - "로그인" 버튼 → `ApiClient().verifyAuthCode(email, code)`
   - 성공 시 `SessionSecureStorage.saveSession()` + `sessionNotifier.loginSuccess()`

### 4.2 구현 플로우

```
앱 시작 (세션 없음)
  ↓
LoginScreen 표시
  ↓
이메일 입력 → "인증 코드 받기" 클릭
  ↓
POST /v1/auth/send-code
  ↓
6자리 코드 입력 화면 표시
  ↓
코드 입력 → "로그인" 클릭
  ↓
POST /v1/auth/verify
  ↓
SessionSecureStorage에 session_token 저장
  ↓
MainScaffold로 전환 (홈 화면)
```

### 4.3 세션 저장

- **저장소**: `lib/util/session_secure_storage.dart` (FlutterSecureStorage)
- iOS: Keychain, Android: EncryptedSharedPreferences
- `session_token`, `session_expires_at` 저장

### 4.4 자동 로그인

- 앱 시작 시 `SessionNotifier.build()`에서 Secure Storage 비동기 읽기
- 만료 전이면 MainScaffold, 만료/없으면 LoginScreen

---

## 5. 이메일 서비스 설정

상세 설정은 다음 문서를 참조하세요:

- **[SyncFlow 이메일 서비스 설정 가이드](./SyncFlow_이메일_서비스_설정_가이드.md)**
  - Gmail 앱 비밀번호 생성 방법
  - .env 파일 설정 (SMTP_HOST, SMTP_USER, SMTP_PASSWORD 등)
  - FROM_NAME: "SyncFlow"

---

## 6. 권장 구현 순서

1. **MySQL syncflow_db 스키마 생성** (users, email_verifications, sessions)
2. **이메일 서비스 설정** (.env, EmailService.send_login_code)
3. **백엔드 API 구현** (auth.py)
4. **프론트엔드 UI 구현** (login_screen.dart, SessionSecureStorage)
5. **테스트 및 검증**

---

## 7. 보안 고려사항

1. **인증 코드 만료**: 10분 (expires_at)
2. **시도 제한**: attempt_count 5회 초과 시 무효화
3. **code_hash 저장**: 평문 저장 금지, SHA256 해시만 저장
4. **세션 토큰**: Secure Storage에 암호화 저장
5. **개인정보 고지**: 로그인 화면 진입 시 이메일 수집 목적/범위 고지 (마켓 정책)

---

## 참고 문서

- [SyncFlow_인증코드와_세션_설명.md](./SyncFlow_인증코드와_세션_설명.md) - 6자리 코드, code_hash, session_token 상세
- [미니멀_협업_칸반_앱_계정_인증_아키텍처_설계서_v1.md](../syncflow/미니멀_협업_칸반_앱_계정_인증_아키텍처_설계서_v1.md)

---

**마지막 업데이트**: 2026-03-02
