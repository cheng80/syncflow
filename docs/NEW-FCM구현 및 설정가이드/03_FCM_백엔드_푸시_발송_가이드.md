# FCM 백엔드 푸시 발송 가이드 (공용, 2026-03-04 검증)

## 핵심 원칙

- 클라이언트에서 직접 FCM 송신 금지
- 신뢰 가능한 서버 환경에서만 송신
- 레거시 API가 아닌 **HTTP v1 / Admin SDK** 사용

## 공용값 + SyncFlow 예시

| 항목 | 공용 Placeholder | SyncFlow 예시 |
|---|---|---|
| 사용자 식별자 | `<USER_ID>` | `user_id` (`/v1/auth/me` 응답 기준) |
| API base | `<BACKEND_BASE_URL>` | `http://10.0.2.2:8000` / `http://127.0.0.1:8000` |
| API prefix | `<API_PREFIX>` | `/v1` |
| 토큰 테이블 | `push_tokens` | `push_tokens` (todo 계획과 정합) |

## 1. 현 시점 필수 사항

- FCM Legacy HTTP/XMPP는 2023-06-20 deprecated
- Legacy API shutdown 시작일: **2024-07-22**
- 신규/운영 시스템은 HTTP v1 또는 Admin SDK 기준으로 구현

## 2. 발송 코드

### 공용 버전 (Admin SDK)

```python
from firebase_admin import messaging

def send_to_token(token: str, title: str, body: str, data: dict[str, str]):
    message = messaging.Message(
        token=token,
        notification=messaging.Notification(title=title, body=body),
        data=data,
    )
    return messaging.send(message)
```

### SyncFlow 버전 (권장 추가안)

경로 예시: `fastapi/app/utils/fcm_service.py`

```python
from firebase_admin import messaging

class FcmService:
    @staticmethod
    def send_to_user_tokens(tokens: list[str], title: str, body: str, data: dict[str, str]) -> int:
        success = 0
        for token in tokens:
            msg = messaging.Message(
                token=token,
                notification=messaging.Notification(title=title, body=body),
                data=data,
            )
            messaging.send(msg)
            success += 1
        return success
```

## 3. API 엔드포인트

### 공용 버전

```text
POST /api/push-tokens
DELETE /api/push-tokens/{token}
POST /api/push-events
```

### SyncFlow 버전 (권장 추가안)

```text
POST /v1/push-tokens
DELETE /v1/push-tokens/{token}
POST /v1/push-events
```

FastAPI 라우터 예시:

```python
from fastapi import APIRouter, Depends

router = APIRouter()

@router.post("/push-events")
async def push_events(...):
    # 1) 수신자 조회
    # 2) 토큰 조회(push_tokens)
    # 3) FcmService 호출
    return {"ok": True}
```

## 4. 이벤트 payload

### 공용 버전

```json
{
  "type": "mention_created",
  "board_id": "<BOARD_ID>",
  "card_id": "<CARD_ID>",
  "target_user_id": "<USER_ID>"
}
```

### SyncFlow 버전

```json
{
  "type": "mention_created",
  "board_id": "101",
  "card_id": "555",
  "target_user_id": "123"
}
```

## 5. 운영 정책

- 무효 토큰 즉시 비활성화
- 동일 이벤트 중복 발송 방지 키 적용
- 실패 재시도 + DLQ 구성
- 발송 성공률/실패률/무효토큰률 모니터링

## 6. 검증 체크리스트

- [ ] Admin SDK 또는 HTTP v1 인증 성공
- [ ] 단일 토큰 발송 성공
- [ ] 멀티캐스트(최대 500) 처리 성공
- [ ] 무효 토큰 정리 자동화

## 공식 문서

- https://firebase.google.com/docs/cloud-messaging/send/admin-sdk
- https://firebase.google.com/docs/cloud-messaging/send/v1-api
- https://firebase.google.com/docs/cloud-messaging/migrate-v1
- https://firebase.google.com/docs/cloud-messaging/server
