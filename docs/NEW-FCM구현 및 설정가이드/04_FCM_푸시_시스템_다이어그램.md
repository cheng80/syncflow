# FCM 푸시 시스템 다이어그램 (공용)

## 공용값 + SyncFlow 예시

- 공용 이벤트: `mention_created`, `card_assignee_changed`, `card_status_changed`, `board_invitation_updated`
- SyncFlow 도메인 식별자 예시:
  - `board_id` (보드)
  - `card_id` (카드)
  - `user_id` (사용자)
- SyncFlow API 경로 스타일 예시: `/v1/...`

## 1. 시퀀스 다이어그램

```mermaid
sequenceDiagram
  participant APP as Flutter App
  participant LNP as Local Notifications Plugin
  participant API as Backend API
  participant DB as push_tokens DB
  participant FCM as Firebase Cloud Messaging
  participant DEV as User Device

  APP->>API: POST /api/push-tokens (login/onTokenRefresh)
  API->>DB: upsert token
  Note over API: 도메인 이벤트 발생 (mention_created 등)
  API->>DB: 대상 사용자 활성 토큰 조회
  API->>FCM: send message (Admin SDK or HTTP v1)
  FCM-->>DEV: notification/data message
  DEV-->>APP: onMessage (foreground)
  APP->>LNP: show local notification
  DEV-->>APP: 앱 열기 (getInitialMessage/onMessageOpenedApp)
```

## 2. 컴포넌트 다이어그램

```mermaid
flowchart TB
  subgraph Client
    A[Flutter App]
    B[Firebase Messaging SDK]
    H[flutter_local_notifications]
  end

  subgraph Server
    C[API Server]
    D[Push Service]
    E[(push_tokens)]
    F[(notification_logs)]
  end

  G[FCM Backend]

  A --> C
  C --> D
  D --> E
  D --> F
  D --> G
  G --> B
  B --> A
  A --> H
```

## 3. 이벤트 표준 예시

- `mention_created`
- `card_assignee_changed`
- `card_status_changed`
- `board_invitation_updated`

## 4. 딥링크 파라미터 표준

```json
{
  "type": "mention_created",
  "board_id": "<BOARD_ID>",
  "card_id": "<CARD_ID>",
  "target_user_id": "<USER_ID>"
}
```

## 5. 운영 지표

- 발송 성공률
- 평균 발송 지연
- 무효 토큰 비율
- 딥링크 이동 성공률

## 6. 검증 체크리스트

- [ ] 이벤트별 대상자 계산 정확성
- [ ] 동일 이벤트 중복 발송 방지
- [ ] 탭 시 목표 화면 이동
- [ ] 장애 시 재시도/DLQ 동작
