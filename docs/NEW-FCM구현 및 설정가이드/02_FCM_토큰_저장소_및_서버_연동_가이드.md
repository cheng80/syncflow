# FCM 토큰 저장소 및 서버 연동 가이드 (공용, 2026-03-05 갱신)

본 문서는 **Flutter + Riverpod** 조합을 기본 전제로 작성되었다.

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

### 참고: 앱별 구현 예시 (SyncFlow)

```text
fcm_token
fcm_last_sent_token
fcm_server_synced
fcm_last_sync_attempt
# 저장소 구현은 앱 구조에 맞게 선택 (예: secure storage, key-value storage)
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

### 참고: 앱별 구현 예시 (SyncFlow)

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

### 참고: 앱별 구현 예시 (SyncFlow)

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
Future<void> syncCurrentTokenToServer({
  required String authToken,
  required Future<void> Function(String token) saveLocalToken,
  required Future<void> Function(String token) upsertServerToken,
}) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null || token.isEmpty) return;

  await saveLocalToken(token);

  try {
    await upsertServerToken(token);
  } catch (_) {
    // TODO: 재시도 큐(백오프) 적재
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    await saveLocalToken(newToken);
    try {
      await upsertServerToken(newToken);
    } catch (_) {
      // TODO: 재시도 큐(백오프) 적재
    }
  });
}
```

### 참고: 앱별 구현 예시 (SyncFlow)

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
