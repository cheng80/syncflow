# 실시간 경량 협업 보드

## WebSocket 이벤트 스펙 v1 (MVP)

본 문서는 \*\*서버(FastAPI) + 클라이언트(Flutter)\*\*가 동일한 규격으로 실시간 동기화를 구현하기 위한 최소 스펙이다.

---

# 1. 연결 규격

## 1.1 엔드포인트

- `wss://<host>/ws`

## 1.2 인증

- Query 파라미터로 세션 토큰 전달
  - `wss://<host>/ws?token=<session_token>`

서버는 연결 시 아래를 검증한다.

- sessions.session\_token 유효
- revoked=false
- expires\_at > now

검증 실패 시:

- 연결 즉시 종료(close)

---

# 2. 룸(Room) 모델

## 2.1 보드 룸

- 룸 키: `board:<board_id>`
- 클라이언트는 로그인 후 보드 진입 시 **JOIN\_BOARD**를 보내 룸에 참여한다.
- 서버는 board\_members 권한을 확인하고 룸 join을 허용/거부한다.

---

# 3. 메시지 공통 포맷

모든 메시지는 JSON이며, 다음 envelope를 따른다.

```json
{
  "type": "<EVENT_TYPE>",
  "req_id": "<client-generated uuid> (optional)",
  "ts": 0,
  "data": {}
}
```

필드 규칙:

- `type` (필수): 이벤트 타입
- `req_id` (선택): 요청/응답 매칭용. 클라이언트가 생성(uuid)하여 요청에 포함
- `ts` (선택): epoch ms. 서버는 응답에 채워줄 수 있음
- `data` (필수): 이벤트 payload

응답/ACK 규칙:

- 클라이언트 요청(변경 작업)은 `req_id` 포함 권장
- 서버는 성공 시 동일 `req_id`를 포함한 ACK 또는 최종 상태 이벤트를 broadcast
- 실패 시 `ERROR` 이벤트로 응답(동일 req\_id 포함)

---

# 4. 연결 수명 주기 이벤트

## 4.1 서버 → 클라이언트

### CONNECTED

연결 직후 서버가 전송(선택).

```json
{ "type": "CONNECTED", "data": { "server_time": 0 } }
```

### ERROR

모든 실패는 ERROR로 통일.

```json
{
  "type": "ERROR",
  "req_id": "<optional>",
  "data": {
    "code": "<ERROR_CODE>",
    "message": "<human readable>",
    "detail": {}
  }
}
```

대표 ERROR\_CODE:

- `AUTH_REQUIRED` (토큰 없음)
- `AUTH_INVALID` (토큰 무효/만료)
- `FORBIDDEN` (권한 없음)
- `NOT_FOUND` (대상 없음)
- `VALIDATION_ERROR` (입력값 오류)
- `LOCKED` (락으로 인해 수정 불가)
- `CONFLICT` (버전 충돌/상태 불일치)

---

# 5. 보드 참가 / Presence

## 5.1 클라이언트 → 서버

### JOIN\_BOARD

```json
{
  "type": "JOIN_BOARD",
  "req_id": "<uuid>",
  "data": { "board_id": 123 }
}
```

### LEAVE\_BOARD

```json
{
  "type": "LEAVE_BOARD",
  "req_id": "<uuid>",
  "data": { "board_id": 123 }
}
```

## 5.2 서버 → 클라이언트

### BOARD\_JOINED (ACK)

JOIN 성공 시 요청자에게 전송.

```json
{
  "type": "BOARD_JOINED",
  "req_id": "<uuid>",
  "data": {
    "board_id": 123,
    "members_online": [
      { "user_id": 1, "display": "kim" },
      { "user_id": 2, "display": "lee" }
    ]
  }
}
```

### PRESENCE\_JOINED (broadcast)

```json
{
  "type": "PRESENCE_JOINED",
  "data": { "board_id": 123, "user": { "user_id": 2, "display": "lee" } }
}
```

### PRESENCE\_LEFT (broadcast)

```json
{
  "type": "PRESENCE_LEFT",
  "data": { "board_id": 123, "user_id": 2 }
}
```

Presence 정책(MVP):

- 보드 룸에 join된 연결만 온라인으로 카운트
- 재접속 시 JOIN\_BOARD 재호출

---

# 6. Soft Lock (카드 편집 잠금)

목표: 동시 편집 충돌 최소화(저비용).

## 6.1 서버 저장소 (MVP)

- FastAPI 단일 인스턴스 기준 **메모리 저장**
- 키: `card_id`
- 값: `{ locked_by_user_id, expires_at }`

## 6.2 정책

- TTL: 30초
- RENEW: 10초마다 권장
- **보드 멤버 누구나** ACQUIRE 가능
- 락 소유자만 RENEW/RELEASE 가능
- TTL 만료 시 자동 해제
- 연결 종료(disconnect) 시 서버는 즉시 해제하거나 TTL로 자연 해제

## 6.3 클라이언트 → 서버

### LOCK\_ACQUIRE

```json
{
  "type": "LOCK_ACQUIRE",
  "req_id": "<uuid>",
  "data": { "board_id": 123, "card_id": 555 }
}
```

### LOCK\_RENEW

```json
{
  "type": "LOCK_RENEW",
  "req_id": "<uuid>",
  "data": { "board_id": 123, "card_id": 555 }
}
```

### LOCK\_RELEASE

```json
{
  "type": "LOCK_RELEASE",
  "req_id": "<uuid>",
  "data": { "board_id": 123, "card_id": 555 }
}
```

## 6.4 서버 → 클라이언트

### CARD\_LOCKED (broadcast)

```json
{
  "type": "CARD_LOCKED",
  "data": {
    "board_id": 123,
    "card_id": 555,
    "locked_by": { "user_id": 2, "display": "lee" },
    "expires_at": 0
  }
}
```

### CARD\_UNLOCKED (broadcast)

```json
{
  "type": "CARD_UNLOCKED",
  "data": { "board_id": 123, "card_id": 555 }
}
```

서버 거부 시:

- `ERROR` with code `LOCKED` (이미 다른 사용자가 잠금)

---

# 7. 카드 이벤트 (MVP)

## 7.0 카드 상태/삭제 정책

- 카드 삭제는 1차에서 **물리 삭제(CARD\_DELETE) 미사용**
- 카드 정리는 `status`로 처리
  - `active`: 기본
  - `done`: 완료(UX 용)
  - `archived`: 아카이브(목록에서 기본 숨김)

> “Done 컬럼”은 `status=done`으로 처리할 수 있으며, 별도의 정리(숨김/삭제 대체)는 `status=archived`로 처리한다.

## 7.0.1 Title/Description 수정 정책 (확정)

- **Title**: soft lock 미적용
  - 저장(Commit) 시점에만 서버 반영
  - 충돌 시 Last Write Wins (LWW)
  - 서버는 `updated_at`, `updated_by` 기준으로 최종 상태 broadcast
- **Description**: soft lock 강제
  - LOCK 미보유 시 `ERROR: LOCKED` 반환

이 정책은 1차 MVP 기준으로 고정한다.

## 7.0.2 카드 소유자 잠금(Owner Lock) — 1차 포함

협업 중 특정 카드를 보호하기 위한 강제 잠금.

- 필드: `owner_lock`(bool), `owner_lock_by`(user\_id), `owner_lock_at`
- 권한: `board owner`만 설정/해제 가능
- 효과: `owner_lock=true`일 때
  - owner 외 사용자의 `CARD_UPDATE / CARD_MOVE / CARD_ARCHIVE` 요청은 `ERROR: FORBIDDEN` 또는 `ERROR: LOCKED`

이벤트:

- `CARD_OWNER_LOCK_SET` (요청)
- `CARD_OWNER_LOCK_CHANGED` (broadcast)

주의: 모든 카드 변경 이벤트는 **board 룸 broadcast**가 원칙이다. **board 룸 broadcast**가 원칙이다.

## 7.1 클라이언트 → 서버

### CARD\_CREATE

```json
{
  "type": "CARD_CREATE",
  "req_id": "<uuid>",
  "data": {
    "board_id": 123,
    "column_id": 10,
    "title": "new task",
    "description": "",
    "priority": "medium",
    "assignee_id": null,
    "due_date": null,
    "position": 1000
  }
}
```

### CARD\_MOVE

```json
{
  "type": "CARD_MOVE",
  "req_id": "<uuid>",
  "data": {
    "board_id": 123,
    "card_id": 555,
    "from_column_id": 10,
    "to_column_id": 11,
    "position": 2500
  }
}
```

### CARD\_UPDATE

- title/description/priority/assignee/due\_date/status 수정에 사용
- **설명(description) 편집은 soft lock 권장** (MVP에서는 서버가 lock 미보유 시 `LOCKED`로 거부하도록 설정 가능)

```json
{
  "type": "CARD_UPDATE",
  "req_id": "<uuid>",
  "data": {
    "board_id": 123,
    "card_id": 555,
    "patch": {
      "title": "updated",
      "description": "- item
- item2",
      "priority": "high",
      "assignee_id": 2,
      "due_date": null,
      "status": "active"
    }
  }
}
```

### CARD\_ARCHIVE (1차 포함: 소프트 삭제)

카드 정리는 삭제 대신 `status=archived`로 처리한다.

```json
{
  "type": "CARD_ARCHIVE",
  "req_id": "<uuid>",
  "data": { "board_id": 123, "card_id": 555 }
}
```

### CARD\_RESTORE (옵션: 1차 포함 여부 결정)

```json
{
  "type": "CARD_RESTORE",
  "req_id": "<uuid>",
  "data": { "board_id": 123, "card_id": 555 }
}
```

## 7.2 서버 → 클라이언트

서버는 성공 시 **최종 상태**를 내려준다(클라 낙관적 UI 확정 목적).

### CARD\_CREATED (broadcast)

```json
{
  "type": "CARD_CREATED",
  "data": { "board_id": 123, "card": { "id": 555, "column_id": 10, "title": "new", "position": 1000, "updated_at": 0 } }
}
```

### CARD\_MOVED (broadcast)

```json
{
  "type": "CARD_MOVED",
  "data": { "board_id": 123, "card_id": 555, "column_id": 11, "position": 2500, "updated_at": 0 }
}
```

### CARD\_UPDATED (broadcast)

```json
{
  "type": "CARD_UPDATED",
  "data": { "board_id": 123, "card_id": 555, "patch": { "title": "updated" }, "updated_at": 0 }
}
```

### CARD\_ARCHIVED (broadcast)

```json
{ "type": "CARD_ARCHIVED", "data": { "board_id": 123, "card_id": 555, "status": "archived", "updated_at": 0 } }
```

### CARD\_RESTORED (broadcast)

```json
{ "type": "CARD_RESTORED", "data": { "board_id": 123, "card_id": 555, "status": "active", "updated_at": 0 } }
```

실패 시:

- `ERROR` with `VALIDATION_ERROR` / `FORBIDDEN` / `LOCKED`

---

# 8. 컬럼 이벤트 (1차 옵션)

MVP에서 컬럼 편집을 최소로 유지하려면 아래는 2차로 미룰 수 있다.

- COLUMN\_CREATE
- COLUMN\_UPDATE
- COLUMN\_DELETE
- COLUMN\_REORDER

(필요 시 v1.0.1로 별도 추가)

---

# 9. 재연결 / 동기화 정책 (MVP)

## 9.1 재연결

- 클라이언트는 연결 끊김 시 자동 재시도(지수 백오프 권장)
- 재연결 성공 후 반드시 `JOIN_BOARD`를 다시 호출

## 9.2 동기화

MVP 권장 방식:

- 재연결 후 보드 스냅샷은 **REST API**로 재조회
- WS는 이후 변경 이벤트만 수신

---

# 10. 구현 체크리스트

서버:

- WS 연결 시 session\_token 검증
- JOIN\_BOARD 시 board\_members 권한 체크
- 룸 브로드캐스트 유틸
- presence 온라인 목록 관리(메모리)
- soft lock 관리(메모리 + TTL)
- CARD\_\* 이벤트 처리 및 DB 반영

클라이언트:

- WS 연결/재연결 관리
- 보드 진입 시 JOIN\_BOARD
- presence UI 반영
- 카드 상세 편집 진입 시 LOCK\_ACQUIRE
- 편집 중 주기적 LOCK\_RENEW
- 저장/취소 시 LOCK\_RELEASE
- optimistic update 후 서버 이벤트로 확정/롤백

