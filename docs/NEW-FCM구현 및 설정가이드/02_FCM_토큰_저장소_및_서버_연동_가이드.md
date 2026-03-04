# FCM 토큰 저장소 및 서버 연동 가이드 (공용, 2026-03-04 검증)

## 목적

클라이언트 토큰 수명주기(발급/갱신/비활성화)를 서버 상태와 일치시키는 표준을 정의한다.

## 공용값 + SyncFlow 예시

- 공용 엔드포인트 예시:
  - `POST /api/push-tokens`
  - `DELETE /api/push-tokens/{token}`
- SyncFlow API 스타일 예시:
  - Base URL: `http://10.0.2.2:8000` (Android emulator), `http://127.0.0.1:8000` (iOS/기타)
  - Prefix: `/v1`
  - 권장 추가안: `POST /v1/push-tokens`, `DELETE /v1/push-tokens/{token}`

## 1. 로컬 저장 구조

### 공용 버전

```text
fcm_token
fcm_last_sent_token
fcm_server_synced
fcm_last_sync_attempt
```

### SyncFlow 버전

```text
fcm_token
fcm_last_sent_token
fcm_server_synced
fcm_last_sync_attempt
# 저장소 구현은 Riverpod + GetStorage(또는 secure storage) 기준 권장
```

## 2. 토큰 API

### 공용 버전

`POST /api/push-tokens`

```json
{
  "user_id": "<USER_ID>",
  "platform": "ios|android|web",
  "token": "<FCM_TOKEN>",
  "device_id": "<DEVICE_ID>",
  "app_version": "<APP_VERSION>"
}
```

### SyncFlow 버전

`POST /v1/push-tokens` (권장 추가안)

```json
{
  "user_id": 123,
  "platform": "android",
  "token": "fcm_token_string",
  "device_id": "android-emulator-5554",
  "app_version": "1.0.0"
}
```

SyncFlow 인증 헤더 예시:

```http
X-Session-Token: <session_token>
Content-Type: application/json
```

## 3. DB 스키마

### 공용 버전

```sql
CREATE TABLE push_tokens (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id VARCHAR(64) NOT NULL,
  platform VARCHAR(16) NOT NULL,
  token VARCHAR(512) NOT NULL,
  device_id VARCHAR(128),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_platform_token (platform, token),
  INDEX idx_user_active (user_id, is_active)
);
```

### SyncFlow 버전

```sql
CREATE TABLE push_tokens (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  platform VARCHAR(16) NOT NULL,
  token VARCHAR(512) NOT NULL,
  device_id VARCHAR(128),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_platform_token (platform, token),
  INDEX idx_user_active (user_id, is_active)
);
```

## 4. Flutter 동기화 코드

### 공용 버전

```dart
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
  // 1) 로컬 저장
  // 2) 서버 upsert API 호출
  // 3) 실패 시 재시도 큐 적재
});
```

### SyncFlow 버전

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:syncflow/util/common_util.dart';

Future<void> syncTokenToSyncFlow({
  required int userId,
  required String sessionToken,
}) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;

  final baseUrl = getApiBaseUrl();
  await http.post(
    Uri.parse('$baseUrl/v1/push-tokens'),
    headers: {
      'Content-Type': 'application/json',
      'X-Session-Token': sessionToken,
    },
    body: jsonEncode({
      'user_id': userId,
      'platform': 'android',
      'token': token,
    }),
  );
}
```

## 5. 검증 체크리스트

- [ ] 로그인 시 토큰 등록 성공
- [ ] 토큰 갱신 시 서버값 업데이트
- [ ] 로그아웃 시 비활성화
- [ ] 무효 토큰 정리 동작 확인

## 공식 문서

- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://firebase.google.com/docs/cloud-messaging/server
