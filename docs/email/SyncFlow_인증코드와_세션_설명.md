# SyncFlow 인증코드와 세션 설명

SyncFlow 로그인에서 사용하는 6자리 인증 코드와 세션 토큰의 생성·저장·검증 방법을 설명합니다.

**대상**: SyncFlow (소규모 팀 협업 칸반 앱)  
**갱신일**: 2026-03-02

---

## 📋 목차

1. [개요](#1-개요)
2. [SyncFlow에서의 사용 방식](#2-syncflow에서의-사용-방식)
3. [인증 코드 (Auth Code)](#3-인증-코드-auth-code)
4. [코드 해시 (code_hash)](#4-코드-해시-code_hash)
5. [세션 토큰 (session_token)](#5-세션-토큰-session_token)
6. [사용 흐름](#6-사용-흐름)
7. [보안 고려사항](#7-보안-고려사항)
8. [코드 위치](#8-코드-위치)

---

## 1. 개요

SyncFlow는 **이메일 6자리 인증 코드**로 본인 확인 후 **세션 토큰(UUID4)**을 발급합니다.

- **인증 코드**: 이메일로 발송되어 사용자가 입력하는 6자리 숫자 (일회용, 10분 만료)
- **code_hash**: 서버에 저장할 때 SHA256 해시로 저장 (평문 저장 금지)
- **session_token**: 인증 성공 시 발급되는 UUID4 (14일 유효, API/WebSocket 인증에 사용)

---

## 2. SyncFlow에서의 사용 방식

### 단순화된 흐름

```
1. 인증 코드 발송
   → 클라이언트: email 전송
   → 서버: 6자리 코드 생성 → code_hash 저장 → 이메일 발송

2. 인증 코드 검증 → 로그인
   → 사용자: 이메일에서 받은 6자리 코드 입력
   → 클라이언트: email + code 전송
   → 서버: code_hash 비교 → users 생성/조회 → sessions 생성 → session_token 반환

3. 세션 유지
   → 클라이언트: session_token을 Secure Storage에 저장
   → API/WebSocket 요청 시 session_token으로 인증
```

### 사용자 관점

- ✅ **인증 코드만 입력**: 이메일로 받은 6자리 숫자 입력
- ✅ **세션 자동 유지**: 앱 재시작 시 Secure Storage에서 복원

---

## 3. 인증 코드 (Auth Code)

### 정의
- **형식**: 6자리 숫자
- **범위**: 0~9 조합 (secrets 모듈 사용)
- **예시**: `123456`, `789012`

### 생성 방법 (SyncFlow 구현)
```python
import secrets

# 6자리 숫자 생성 (암호학적 안전)
code = "".join(secrets.choice("0123456789") for _ in range(6))
# 결과 예시: "123456"
```

### 특징
- **사용자 친화적**: 짧고 기억하기 쉬움
- **입력 용이**: 숫자만 입력
- **이메일 발송**: 사용자 이메일로 직접 전달
- **만료**: 10분 (expires_at)

---

## 4. 코드 해시 (code_hash)

### 정의
- **형식**: SHA256 해시 (64자 16진수)
- **용도**: DB에 평문 코드를 저장하지 않기 위함

### 생성 방법
```python
import hashlib

code = "123456"
code_hash = hashlib.sha256(code.encode("utf-8")).hexdigest()
# 결과 예시: "8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92"
```

### 검증 방법
```python
# 사용자 입력 code를 해시하여 저장된 code_hash와 비교
input_hash = hashlib.sha256(code.encode("utf-8")).hexdigest()
if input_hash == stored_code_hash:
    # 인증 성공
```

### 데이터베이스 저장
- **테이블**: `email_verifications`
- **컬럼**: `code_hash` (CHAR(64))
- **평문 저장 금지**: 보안상 code_hash만 저장

---

## 5. 세션 토큰 (session_token)

### 정의
- **형식**: UUID4 (36자, 예: `550e8400-e29b-41d4-a716-446655440000`)
- **용도**: API/WebSocket 인증, 로그인 상태 유지

### 생성 방법
```python
import uuid

session_token = str(uuid.uuid4())
```

### 클라이언트 저장
- **저장소**: FlutterSecureStorage (iOS Keychain, Android EncryptedSharedPreferences)
- **저장 키**: `syncflow_session_token`, `syncflow_session_expires_at`
- **만료**: 14일 (서버 sessions.expires_at 기준)

### 사용
- REST API: `Authorization` 헤더 또는 요청 body에 session_token 포함
- WebSocket: `ws://server/ws?token=<session_token>`

---

## 6. 사용 흐름

### 6.1 인증 코드 발송

```
1. 사용자가 로그인 화면에서 이메일 입력
   ↓
2. "인증 코드 받기" 클릭
   ↓
3. 클라이언트 API 호출
   POST /v1/auth/send-code
   { "email": "user@example.com" }
   ↓
4. 서버 처리
   - 6자리 코드 생성: secrets.choice
   - code_hash = sha256(code)
   - email_verifications에 INSERT (email, code_hash, expires_at)
   - EmailService.send_login_code() 이메일 발송
   ↓
5. 사용자에게 "이메일을 확인하세요" 안내
```

### 6.2 인증 코드 검증 → 로그인

```
1. 사용자가 이메일에서 받은 6자리 코드 입력
   ↓
2. "로그인" 클릭
   ↓
3. 클라이언트 API 호출
   POST /v1/auth/verify
   { "email": "user@example.com", "code": "123456" }
   ↓
4. 서버 검증
   - (email, code_hash)로 email_verifications 조회
   - expires_at 확인
   - attempt_count 확인 (5회 제한)
   ↓
5. 인증 성공 시
   - users 생성/조회
   - sessions에 session_token INSERT
   - email_verifications 레코드 삭제
   - session_token, expires_at, user_id 반환
   ↓
6. 클라이언트
   - SessionSecureStorage.saveSession(token, expires_at)
   - MainScaffold로 전환
```

---

## 7. 보안 고려사항

### 7.1 인증 코드
- ⚠️ **예측 가능**: 6자리 숫자 (1,000,000개 조합)
- ✅ **만료 시간**: 10분 후 자동 만료
- ✅ **일회용**: 인증 성공 후 삭제
- ✅ **시도 제한**: attempt_count 5회 초과 시 무효화

### 7.2 code_hash 저장
- ✅ **평문 저장 금지**: DB 유출 시에도 코드 복원 불가
- ✅ **SHA256**: 표준 해시 알고리즘 사용

### 7.3 세션 토큰
- ✅ **Secure Storage**: 클라이언트에 암호화 저장
- ✅ **만료**: 14일
- ✅ **로그아웃**: sessions.revoked = TRUE

---

## 8. 코드 위치

### 백엔드
- **API**: `fastapi/app/api/auth.py`
  - `send_code()`, `verify()`, `logout()`
- **이메일 발송**: `fastapi/app/utils/email_service.py`
  - `send_login_code()`

### 데이터베이스
- **테이블**: `email_verifications`, `users`, `sessions` (syncflow_db)
- **스키마**: `fastapi/mysql/init_schema.sql`

### 프론트엔드
- **로그인 화면**: `lib/view/auth/login_screen.dart`
- **세션 저장**: `lib/util/session_secure_storage.dart`
- **세션 상태**: `lib/vm/session_notifier.dart`
- **API 클라이언트**: `lib/service/api_client.dart`

### 참고 문서
- [SyncFlow_이메일_로그인_구현_가이드.md](./SyncFlow_이메일_로그인_구현_가이드.md)
- [미니멀_협업_칸반_앱_계정_인증_아키텍처_설계서_v1.md](../syncflow/미니멀_협업_칸반_앱_계정_인증_아키텍처_설계서_v1.md)

---

**마지막 업데이트**: 2026-03-02
